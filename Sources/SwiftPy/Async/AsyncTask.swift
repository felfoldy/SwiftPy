//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import Foundation
import SwiftUI

typealias TaskResult = PythonConvertible & Sendable

/// An awaitable unit of asynchronous work.
///
/// Calling an `async def` function creates a task without immediately running
/// its body. The task starts when it is awaited, passed to ``asyncio.gather``,
/// or started with ``resume``. Awaiting it returns the coroutine's value or
/// raises its error.
///
/// Use ``is_done`` to check whether work has finished and ``result`` to
/// inspect a successful result without awaiting again. A running task can be
/// stopped with ``cancel``, and the current task can publish console progress
/// with ``set_progress``.
///
/// ```python
/// import asyncio
///
/// async def answer():
///     await asyncio.sleep(1)
///     return 42
///
/// task = answer()
/// print(task.is_done)  # False
///
/// value = await task
/// print(value)         # 42
/// print(task.is_done)  # True
/// print(task.result)   # 42
/// ```
@Scriptable
@MainActor
public class AsyncTask: PythonBindable {
    /// Whether the task has finished.
    ///
    /// Returns `False` before the task starts and while it is running. Returns
    /// `True` after it produces a value or finishes with an error.
    ///
    /// ```python
    /// task = asyncio.sleep(1)
    /// print(task.is_done)  # False
    ///
    /// await task
    /// print(task.is_done)  # True
    /// ```
    public var isDone: Bool { outcome != nil }

    /// The value produced by a successfully completed task.
    ///
    /// Returns the coroutine's value after successful completion. Returns `None`
    /// before completion, after failure, or when the coroutine itself returned
    /// `None`. Await the task when these cases must be distinguished, because
    /// awaiting propagates errors.
    ///
    /// ```python
    /// async def make_value():
    ///     return "ready"
    ///
    /// task = make_value()
    /// print(task.result)  # None
    ///
    /// await task
    /// print(task.result)  # ready
    /// ```
    public var result: PyObject? {
        guard case let .success(value) = outcome else { return nil }
        return value
    }

    internal var task: Task<Void, Never>?
    internal var outcome: Result<PyObject?, PythonError>?

    private var traceEntry: LineTracer.Entry?

    /// The work to run, held until the task is first started.
    /// Returns the task's result, or `nil` if it produces none.
    private var pendingWork: (() async throws -> PyObject?)?

    /// Creates a task that drives a Python generator-based coroutine.
    ///
    /// generator: The Python generator to advance until it returns. CPython
    /// hands back a real coroutine, which is sent into rather than iterated.
    init(generator: PyObject) throws(PythonError) {
#if cpython
        pendingWork = {
            try await PyRuntime.drive(generator) { request in
                // A stop request cancels this task; unwind instead of sending
                // the coroutine forward again.
                try Task.checkCancellation()

                guard let task = AsyncTask(request) else {
                    throw PythonError.TypeError("cannot await a \(request.typeName)")
                }
                return try await task.untilCompletes() ?? .none
            }
        }
#else
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
#endif
    }

    private init(work: @escaping () async throws -> PyObject?) {
        pendingWork = work
    }

    /// Start the task without waiting for it to finish.
    ///
    /// Returns `None`. Calling this more than once has no effect. Most code
    /// should await the task or pass it to ``asyncio.gather`` instead; use
    /// `resume()` only when work should begin before it is awaited.
    public func resume() {
        guard let work = pendingWork else { return }
        pendingWork = nil
        let context = InterpreterExecutionContext.current
        traceEntry = context.traceRecorder?.entries.last {
            $0.contextId == context.contextId
        }
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

    func __iter__() -> AsyncTask {
        resume()
        return self
    }

    /// CPython reaches an awaitable through `__await__`, which has to be an
    /// iterator; this one hands the task to the coroutine driver.
    func __await__() throws(PythonError) -> PyObject {
#if cpython
        resume()
        return try PyRuntime.awaitable(yielding: try toPython())
#else
        // pocketpy awaits by iterating, so nothing calls this.
        throw .RuntimeError("__await__ is CPython's")
#endif
    }

    func __next__() throws(PythonError) -> AsyncTask {
        resume()
        guard let outcome else { return self }
        let value = try outcome.get()
#if cpython
        throw .StopIteration("\(String(describing: value))")
#else
        throw .StopIteration(value?.reference)
#endif
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

    deinit {
        task?.cancel()
    }

    /// Request cancellation of a running task.
    ///
    /// Returns `None`. Cancellation is cooperative: the task stops when its
    /// coroutine next reaches an asynchronous suspension point. Calling this on
    /// a task that has not started or has already finished has no effect. Awaiting
    /// a task after cancellation raises its cancellation error.
    public func cancel() {
        task?.cancel()
    }

    /// Update the task's console progress indicator.
    ///
    /// progress: Completion from `0.0` to `1.0`. Pass `None` to show
    /// indeterminate progress.
    ///
    /// Returns `None`. Call this from asynchronous work on the value returned
    /// by ``asyncio.current_task``.
    ///
    /// ```python
    /// import asyncio
    ///
    /// async def work():
    ///     task = asyncio.current_task()
    ///     for step in range(4):
    ///         task.set_progress(step / 3)
    ///         await asyncio.sleep(1)
    ///
    /// await work()
    /// ```
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
    /// The task for an awaitable Python handed over: one of these as it is,
    /// anything else -- a pocketpy generator, a CPython coroutine -- driven.
    public static func from(_ awaitable: PyObject) throws(PythonError) -> AsyncTask {
        if let task = AsyncTask(awaitable) { return task }
        return try AsyncTask(generator: awaitable)
    }

    public convenience init(_ task: @escaping () async throws -> Void) {
        self.init {
            try await task()
            return nil
        }
    }

    public convenience init<T: PythonConvertible>(_ task: @escaping () async throws -> T) where T: Sendable {
        // Spelled out: `self.init { ... }` picks this same initializer back up
        // when the closure returns a PyObject, and recurses forever.
        self.init(work: {
            #if cpython
            try await task().toPython()
            #else
            py.retain(try await task())
            #endif
        })
    }

    @discardableResult
    public func untilCompletes() async throws(PythonError) -> PyObject? {
        resume()
        await task?.value
        return try outcome?.get()
    }
}
