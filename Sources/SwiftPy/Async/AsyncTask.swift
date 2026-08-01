//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import Foundation
import SwiftUI

typealias TaskResult = PythonConvertible & Sendable

@Scriptable
@MainActor
public class AsyncTask {
    /// Whether the task has finished, successfully or with an error.
    public var isDone: Bool { outcome != nil }

    internal var task: Task<Void, Never>?

    /// The task's outcome once finished: the produced value or a raised error.
    var outcome: Result<PyObject?, PythonError>?

    /// The produced value once the task has finished successfully; `nil` otherwise.
    public var result: PyObject? {
        guard case let .success(value) = outcome else { return nil }
        return value
    }

    /// The work to run, held until the task is first started.
    /// Returns the task's result, or `nil` if it produces none.
    private var pendingWork: (() async throws -> PyObject?)?

    private init(work: @escaping () async throws -> PyObject?) {
        pendingWork = work
    }

    init(generator: PyObject) throws(PythonError) {
        let iterator = try py.retain(py.iter(generator.reference))

        pendingWork = {
            do {
                while true {
                    do {
                        let next = try py.next(iterator.reference)

                        // Fix a loop if any child task fails.
                        if let child = AsyncTask(next) {
                            child.resume()
                            _ = await child.task?.value
                        } else {
                            try await Task.sleep(nanoseconds: 1)
                        }
                    } catch let error as PythonError where error.type == .StopIteration {
                        return py.retain(error.value)
                    }
                }
            } catch {
                // iteration ended with an error
                return nil
            }
        }
    }

    /// Starts the underlying work if it hasn't been started yet.
    public func resume() {
        guard let work = pendingWork else { return }
        pendingWork = nil
        task = Task { [self] in
            do {
                outcome = .success(try await work())
            } catch let error as PythonError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.RuntimeError(error.localizedDescription))
            }
        }
    }

    func __iter__() -> AsyncTask {
        resume()
        return self
    }

    func __next__() throws(PythonError) -> AsyncTask {
        resume()
        switch outcome {
        case let .success(value):
            throw .StopIteration(value?.reference)
        case let .failure(error):
            throw error
        case nil:
            return self
        }
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
            try await task()
            return nil
        }
    }

    public convenience init<T: PythonConvertible>(_ task: @escaping () async throws -> T) where T: Sendable {
        self.init {
            py.retain(try await task())
        }
    }

    public func untilCompletes() async {
        resume()
        await task?.value
    }
}
