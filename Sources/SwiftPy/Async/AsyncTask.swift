//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import Foundation
import SwiftUI

typealias TaskResult = PythonConvertible & Sendable

extension Interpreter {
    /// Parses async-aware source and compiles it into a reusable
    /// ``AsyncContext`` without running it. Execute it later with
    /// ``asyncExecute(_:)``.
    func asyncCompile(_ code: String, filename: String, mode: CompileMode) throws(PythonError) -> AsyncContext {
        try AsyncContext(code, filename: filename, mode: mode)
    }

    func asyncExecute(_ code: String, filename: String, mode: CompileMode) async {
        guard let context = try? asyncCompile(code, filename: filename, mode: mode) else {
            return
        }
        await asyncExecute(context)
    }

    func asyncExecute(_ context: AsyncContext) async {
        await withCheckedContinuation { continuation in
            var context = context
            // Only the awaited path resumes through the context; the unmatched
            // path resumes directly below, so its completion stays a no-op to
            // avoid resuming the continuation twice.
            context.completion = context.didMatch ? { continuation.resume() } : {}

            AsyncContext.$current.withValue(context) {
                do {
                    try Interpreter.shared.execute(context.compiledCode, mode: context.mode)

                    if !context.didMatch {
                        continuation.resume()
                    }
                } catch {
                    continuation.resume()
                }
            }
        }
    }
}

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
        let context = AsyncContext.current
        iterator = try py.retain(py.iter(generator.reference))

        // Child tasks created in the loop must not inherit this generator's
        // context, otherwise they would resume its continuation a second time.
        self.task = AsyncContext.$current.withValue(nil) {
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
                                Interpreter.output.view(child.body())
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
                    context?.completion()
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
        let context = AsyncContext.current
        
        self.init {
            do {
                try await task()
                await context?.complete(result: nil)
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

                await context?.complete(result: py.retain(result))

                return result
            } catch {
                Interpreter.output.stderr(error.localizedDescription)
                context?.completion()

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
