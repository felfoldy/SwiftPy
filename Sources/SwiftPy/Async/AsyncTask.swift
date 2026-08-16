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
public class AsyncTask: PythonBindable {
    /// Whether the task has finished, successfully or with an error.
    public var isDone: Bool { outcome != nil }

    internal var task: Task<Void, Never>?
    private var traceEntry: LineTracer.Entry?

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
            while true {
                // A stop request cancels this task; unwind instead of driving
                // the coroutine forward again.
                try Task.checkCancellation()

                do {
                    let next = try py.next(iterator.reference)

                    if let child = AsyncTask(next) {
                        child.resume()
                        await child.task?.value
                    } else {
                        try await Task.sleep(nanoseconds: 1)
                    }
                } catch let error as PythonError where error.type == .StopIteration {
                    return py.retain(error.value)
                }
            }
        }
    }

    /// Starts the underlying work if it hasn't been started yet.
    public func resume() {
        guard let work = pendingWork else { return }
        pendingWork = nil
        traceEntry = InterpreterExecutionContext.current.traceRecorder?.entries.last
        notifyTaskActivity(isActive: true)
        let cancellation = InterpreterExecutionContext.current.cancellation
        let task = Task { [self] in
            do {
                let result = try await AsyncTask.$current.withValue(self) {
                    try await work()
                }
                outcome = .success(result)
            } catch let error as PythonError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.RuntimeError(error.localizedDescription))
            }
            notifyTaskActivity(isActive: false)
        }
        self.task = task
        // A stop request must reach this task even though it runs unstructured
        // and would not inherit cancellation otherwise.
        cancellation?.onCancel { task.cancel() }
    }

    private func notifyTaskActivity(isActive: Bool, progress: Double? = nil) {
        guard let traceEntry, let contextId = traceEntry.contextId else { return }

        Interpreter.shared.connection.send(
            id: contextId,
            .feedback(item: ExecutionFeedback(
                lineNumber: traceEntry.lineNumber,
                type: isActive ? .task(progress: progress) : nil
            ))
        )
    }

    func __iter__() -> AsyncTask {
        resume()
        return self
    }

    func __next__() throws(PythonError) -> AsyncTask {
        resume()
        guard let outcome else { return self }
        let value = try outcome.get()
        throw .StopIteration(value?.reference)
    }

    deinit {
        task?.cancel()
    }

    public func cancel() {
        task?.cancel()
    }

    /// Reports how far the work has got, from 0 to 1, or `None` if indeterminate.
    public func setProgress(_ progress: Double?) {
        notifyTaskActivity(isActive: true, progress: progress)
    }
}

public extension AsyncTask {
    /// The task whose awaited work is running, available to that work and to
    /// everything it awaits.
    @TaskLocal static var current: AsyncTask?
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

    @discardableResult
    public func untilCompletes() async throws(PythonError) -> PyObject? {
        resume()
        await task?.value
        return try outcome?.get()
    }
}
