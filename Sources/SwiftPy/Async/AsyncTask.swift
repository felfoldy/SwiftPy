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
    typealias object = PyAPI.Reference
    
    public var isDone: Bool = false
    public var viewRepresentation: ViewRepresentation?

    internal let task: Task<Void, Never>
    internal static var tasks = [UUID: AsyncTask]()

    var result: object? { self[.result] }

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
            AsyncTask.tasks[id]?[.result] = result
            AsyncTask.tasks[id]?.isDone = true
            AsyncTask.tasks[id] = nil
        }

        AsyncTask.tasks[id] = self
    }

    init(generator: object) throws {
        let context = AsyncContext.current
        
        try Interpreter.printErrors {
            py_iter(generator)
        }
        
        let iter = PyAPI.returnValue.toRegister(5)
        
        let id = UUID()
        self.task = Task {
            while let task = AsyncTask.tasks[id], task.isDone == false {
                if py_next(iter) == 0 {
                    let stack = PyAPI.returnValue.toStack
                    let result = try? stack.reference?.attribute("value")
                    task[.result] = result
                    task.isDone = true
                    await context?.complete(result: result)
                } else {
                    try? await Task.sleep(nanoseconds: 1)
                }
            }
        }
        
        AsyncTask.tasks[id] = self
    }

    deinit {
        task.cancel()
    }

    public func cancel() {
        task.cancel()
    }
}

extension AsyncTask: HasSlots {
    public enum Slot: Int32, CaseIterable {
        case result
    }
}

extension AsyncTask {
    public var view: some View { viewRepresentation?.view }
}

extension AsyncTask {
    public convenience init(_ task: @escaping () async throws -> Void) {
        let context = AsyncContext.current
        
        self.init {
            do {
                try await task()
                await context?.complete(result: Int?.none)
            } catch {
                log.critical(error.localizedDescription)
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
                log.critical(error.localizedDescription)
                context?.completion()

                return nil
            }
        })
    }
    
    public convenience init<T: PythonConvertible>(presenting: any ViewRepresentable, _ task: @escaping () async throws -> T) where T: Sendable {
        self.init(task)
        viewRepresentation = presenting.representation
    }
}
