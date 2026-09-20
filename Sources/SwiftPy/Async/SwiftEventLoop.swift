//
//  SwiftEventLoop.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-13.
//

#if cpython
import Foundation

/// The Swift half of `_swiftpy_asyncio.SwiftEventLoop`: runs what the stdlib
/// loop schedules on the main actor, and bridges futures to Swift awaits.
@MainActor
enum SwiftEventLoop {
    /// Importing installs the loop, so this is where asyncio starts.
    static let module: PyModule = {
        // The Python actor's thread learns the loop as it starts.
        PyRuntime.prepareThread = {
            try? PyRuntime.run("import _swiftpy_asyncio; _swiftpy_asyncio._install_on_this_thread()")
        }
        if let module = py.module("_swiftpy_asyncio") { return module }
        // Import again through importlib for the error py.module swallowed.
        do {
            try py.module("importlib")!.throwing.import_module("_swiftpy_asyncio")
        } catch {
            preconditionFailure("_swiftpy_asyncio failed to import: \(error)")
        }
        preconditionFailure("_swiftpy_asyncio failed to import")
    }()

    // MARK: Scheduling

    private struct Scheduled: Sendable {
        let callback: PyObject
        // Callbacks run on the Python actor, outside the task that scheduled
        // them, so output routing and the current task are carried across.
        let context: InterpreterExecutionContext.Context
        let task: AsyncTask?
    }

    private static var ready: [Scheduled] = []
    private static var drainScheduled = false

    static func schedule(_ callback: PyObject, after delay: Double) {
        let item = Scheduled(callback: callback, context: InterpreterExecutionContext.current, task: AsyncTask.current)
        guard delay > 0 else {
            enqueue(item)
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            enqueue(item)
        }
    }

    private static func enqueue(_ item: Scheduled) {
        ready.append(item)
        guard !drainScheduled else { return }
        drainScheduled = true
        // One task per batch, made in order: the main actor's queue keeps
        // call_soon's FIFO order, which asyncio relies on, and each batch
        // reaches the Python actor in that order too.
        Task { @MainActor in
            drainScheduled = false
            let batch = ready
            ready.removeAll()
            await run(batch)
        }
    }

    /// The callbacks step coroutines: that is where code after an `await`
    /// runs, so it runs where a cell does.
    @PythonActor
    private static func run(_ batch: [Scheduled]) {
        for item in batch {
            InterpreterExecutionContext.$current.withValue(item.context) {
                AsyncTask.$current.withValue(item.task) {
                    // Handle._run reports its own errors to the loop.
                    do { try PyRuntime.call(item.callback) } catch {
                        log.error("event loop callback failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: Futures

    private static var continuations: [Int: CheckedContinuation<PyObject, Never>] = [:]
    private static var nextToken = 0

    /// Waits for a future or task to settle, then reads it the way `await` does.
    static func result(of future: PyObject) async throws(PythonError) -> PyObject? {
        let token = nextToken
        nextToken += 1

        let settled = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                continuations[token] = continuation
                do {
                    try module.throwing.watch(future, token)
                } catch {
                    continuations[token] = nil
                    continuation.resume(returning: future)
                }
            }
        } onCancel: {
            Task { @MainActor in _ = try? future.throwing.cancel() }
        }

        if try settled.throwing.cancelled() {
            throw PythonError(type: "CancelledError", value: "")
        }
        let exception = try settled.throwing.exception()
        if !exception.object.reference.isNone {
            throw PythonError.fromPython(exception.object.reference)
        }
        let value = try settled.throwing.result().object
        return value.reference.isNone ? nil : value
    }

    static func resolve(_ token: Int, _ future: PyObject) {
        continuations.removeValue(forKey: token)?.resume(returning: future)
    }

    /// A future that settles when the task's Swift work does.
    static func future(completing task: AsyncTask) throws(PythonError) -> PyObject {
        let future = try module.throwing.loop.create_future().object
        Task { @MainActor in
            await task.task?.value
            settle(future, with: task.outcome)
        }
        return future
    }

    private static func settle(_ future: PyObject, with outcome: Result<PyObject?, PythonError>?) {
        do {
            switch outcome {
            case .success(let value):
                if try future.throwing.done() { return }
                try future.throwing.set_result(value ?? PyObject.none)
            case .failure(let error):
                try module.throwing.fail(future, error.type, error.value)
            case nil:
                try module.throwing.fail(future, "CancelledError", "")
            }
        } catch {
            log.error("could not settle a future: \(error)")
        }
    }
}
#endif
