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
    public var result: PyObject?

    /// The work to run, held until the task is first started.
    private var pendingWork: (() async -> Void)?

    private init(task: @escaping () async -> Void) {
        pendingWork = task
    }

    private init<T: PythonConvertible>(returns task: @escaping () async -> T?) {
        pendingWork = { [weak self] in
            let result = await task()
            self?.result = py.retain(result)
        }
    }

    init(generator: PyObject) throws(PythonError) {
        iterator = try py.retain(py.iter(generator.reference))

        pendingWork = { [weak self] in
            guard let self else { return }
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
                            child.resume()
                            _ = await child.task?.value
                            child.isDone = true
                        } else {
                            try await Task.sleep(nanoseconds: 1)
                        }
                    } catch let PythonError.StopIteration(result) {
                        self.result = py.retain(result)
                        self.isDone = true
                    }
                }
            } catch {
                // iteration ended with an error
            }
        }
    }

    /// Starts the underlying work if it hasn't been started yet.
    public func resume() {
        guard let work = pendingWork else { return }
        pendingWork = nil
        task = Task { [self] in
            await work()
            isDone = true
        }
    }

    func __iter__() -> AsyncTask {
        resume()
        return self
    }

    func __next__() throws(PythonError) -> AsyncTask {
        resume()
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
        self.init {
            do {
                try await task()
            } catch {
                log.critical("\(error.localizedDescription)")
            }
        }
    }
    
    public convenience init<T: PythonConvertible>(_ task: @escaping () async throws -> T) where T: Sendable {
        self.init(returns: { () async -> T? in
            do {
                return try await task()
            } catch {
                Interpreter.shared.connection.send(id: 0, .stderr(text: error.localizedDescription))
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
        resume()
        await task?.value
    }
}
