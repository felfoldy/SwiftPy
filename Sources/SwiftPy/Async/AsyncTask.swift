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

    init(generator: PyObject) throws(PythonError) {
        iterator = try py.retain(py.iter(generator.reference))

        self.task = Task { [self] in
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
                        self.result = py.retain(result)
                        self.isDone = true
                    }
                }
            } catch {
                // iteration ended with an error
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
        await task?.value
    }
}
