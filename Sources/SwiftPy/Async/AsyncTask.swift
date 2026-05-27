//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import pocketpy
import Foundation
import SwiftUI

typealias TaskResult = PythonConvertible & Sendable

extension Interpreter {
    func asyncExecute(_ code: String, filename: String, mode: CompileMode) async {
        await withCheckedContinuation { continuation in
            let decoder = AsyncContext(code, filename: filename, mode: mode) {
                continuation.resume()
            }
            AsyncContext.current = decoder
            defer { AsyncContext.current = nil }
            
            do {
                try Interpreter.shared.execute(decoder.code, filename: filename, mode: mode)

                if !decoder.didMatch {
                    continuation.resume()
                }
            } catch {
                continuation.resume()
                return
            }
        }
    }
}

@MainActor
@Scriptable
public class AsyncTask: ViewRepresentable {
    public var isDone: Bool = false
    public var viewRepresentation: AnyView?

    internal let task: Task<Void, Never>
    internal static var tasks = [UUID: AsyncTask]()
    
    internal var iterator: PyObject?
    internal var result: PyObject?

    private init(task: @escaping () async -> Void) {
        let id = UUID()
        
        self.task = Task {
            await task()
            AsyncTask.tasks[id]?.isDone = true
            AsyncTask.tasks[id] = nil
        }

        AsyncTask.tasks[id] = self
    }

    private init<T: PythonConvertible>(returns task: @escaping () async -> T?) {
        let id = UUID()
        
        self.task = Task {
            let result = await task()
            AsyncTask.tasks[id]?.result = py.retain(result)
            AsyncTask.tasks[id]?.isDone = true
            AsyncTask.tasks[id] = nil
        }

        AsyncTask.tasks[id] = self
    }

    init(generator: PyObject) throws {
        let context = AsyncContext.current
        iterator = try py.retain(py.iter(generator.reference))

        let id = UUID()
        self.task = Task {
            do {
                while let task = AsyncTask.tasks[id], task.isDone == false {
                    guard let iterator = task.iterator else {
                        throw PythonError.AssertionError("Iterator is missing")
                    }
                    
                    do {
                        let next = try py.next(iterator.reference)

                        // Fix a loop if any child task fails.
                        if let task = AsyncTask(next) {
                            Interpreter.output.view(task.representation)
                            _ = await task.task.value
                            
                            if AsyncContext.current == nil {
                                task.isDone = true
                            }
                        } else {
                            try await Task.sleep(nanoseconds: 1)
                        }

                    } catch let PythonError.StopIteration(result) {
                        task.result = py.retain(result)
                        task.isDone = true
                        await context?.complete(result: result)
                    }
                }
            } catch {
                context?.completion()
            }
            
            AsyncTask.tasks[id] = nil
        }
        
        AsyncTask.tasks[id] = self
    }
    
    func __iter__() -> AsyncTask {
        self
    }
    
    func __next__() throws(PythonError) -> AsyncTask {
        if isDone {
            throw .StopIteration(result?.reference)
        }
        return self
    }

    deinit {
        task.cancel()
    }

    public func cancel() {
        task.cancel()
    }
}

extension AsyncTask {
    public var view: some View { viewRepresentation }
}

extension AsyncTask {
    public convenience init(_ task: @escaping () async throws -> Void) {
        let context = AsyncContext.current
        
        self.init {
            do {
                try await task()
                await context?.complete(result: Int?.none)
            } catch {
                log.critical("\(error.localizedDescription)")
                context?.completion()
            }
        }
    }
    
    public convenience init<T: PythonConvertible>(_ task: @escaping () async throws -> T) where T: Sendable {
        let context = AsyncContext.current

        self.init(returns: { () async -> T? in
            do {
                let result = try await task()

                await context?.complete(result: result)

                return result
            } catch {
                Interpreter.output.stderr(error.localizedDescription)
                context?.completion()

                return nil
            }
        })
    }
    
    public convenience init<T: PythonConvertible>(presenting: any ViewRepresentable, _ task: @escaping () async throws -> T) where T: Sendable {
        self.init(task)
        viewRepresentation = presenting.representation
    }
    
    public func untilCompletes() async {
        await task.value
    }
}
