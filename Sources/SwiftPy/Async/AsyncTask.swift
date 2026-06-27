//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import Foundation
import SwiftUI

typealias TaskResult = PythonConvertible & Sendable

@Scriptable(base: .View)
@MainActor
public class AsyncTask {
    public var isDone: Bool = false
    public var viewRepresentation: AnyView?

    internal var task: Task<Void, Never>?

    internal var iterator: PyObject?
    internal var result: PyObject?

    private init(task: @escaping () async -> Void) {
        self.task = Task { [self] in
            await task()
            isDone = true
        }
    }

    private init<T: PythonConvertible>(returns task: @escaping () async -> T?) {
        self.task = Task { [self] in
            let result = await task()
            self.result = py.retain(result)
            isDone = true
        }
    }

    init(generator: PyObject) throws {
        let context = AsyncCode.current
        iterator = try py.retain(py.iter(generator.reference))

        // Child tasks created in the loop must not inherit this generator's
        // context, otherwise they would resume its continuation a second time.
        self.task = AsyncCode.$current.withValue(nil) {
            Task { [self] in
                do {
                    while !isDone {
                        guard let iterator else {
                            throw PythonError.AssertionError("Iterator is missing")
                        }

                        do {
                            let next = try py.next(iterator.reference)

                            // Fix a loop if any child task fails.
                            if let child = AsyncTask(next) {
                                Interpreter.onDisplay(child.body())
                                _ = await child.task?.value
                                child.isDone = true
                            } else {
                                try await Task.sleep(nanoseconds: 1)
                            }
                        } catch let PythonError.StopIteration(result) {
                            let object = py.retain(result)
                            self.result = object
                            self.isDone = true
                            await context?.complete(result: object)
                        }
                    }
                } catch {
                    context?.completion?()
                }
            }
        }
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

    func body() -> AnyView {
        viewRepresentation ?? AnyView(EmptyView())
    }

    deinit {
        task?.cancel()
    }

    public func cancel() {
        task?.cancel()
    }
}

extension AsyncTask {
    public convenience init(_ task: @escaping () async throws -> Void) {
        let context = AsyncCode.current
        
        self.init {
            do {
                try await task()
                await context?.complete(result: nil)
            } catch {
                log.critical("\(error.localizedDescription)")
                context?.completion?()
            }
        }
    }
    
    public convenience init<T: PythonConvertible>(_ task: @escaping () async throws -> T) where T: Sendable {
        let context = AsyncCode.current

        self.init(returns: { () async -> T? in
            do {
                let result = try await task()

                await context?.complete(result: py.retain(result))

                return result
            } catch {
                Interpreter.shared.connection.send(id: 0, .stderr(text: error.localizedDescription))
                context?.completion?()

                return nil
            }
        })
    }
    
    public convenience init<T: PythonConvertible>(
        presenting: any View,
        _ task: @escaping () async throws -> T
    ) where T: Sendable {
        self.init(task)
        viewRepresentation = AnyView(presenting)
    }
    
    public func untilCompletes() async {
        await task?.value
    }
}
