//
//  CancellationScope.swift
//  SwiftPy
//

/// A part of a run that can be stopped on its own.
@MainActor
public final class CancellationScope {
    let cancellation = RunCancellation(raising: "asyncio.CancelledError")

    nonisolated init() {}

    public var isCancelled: Bool { cancellation.isCancelled }

    /// Stops what's waiting inside the scope, and anything that starts waiting
    /// there afterwards. The rest of the run carries on.
    public func cancel() {
        cancellation.cancel()
    }
}

public extension Interpreter {
    /// Runs `operation` in a cancellation scope inside the current run. What it
    /// awaits or blocks on, such as `time.sleep`, `input()`, `requests.get` or
    /// an awaited task, stops when `scope.cancel()` is called, or when the run
    /// itself is stopped.
    @MainActor
    static func withCancellationScope<T>(
        _ operation: (CancellationScope) async throws -> T
    ) async rethrows -> T {
        let scope = CancellationScope()
        var context = InterpreterExecutionContext.current
        // A stop of the run reaches inside as a stop, not as the scope's cancel.
        if let run = context.cancellation {
            run.onCancel { [weak scope, weak run] in
                scope?.cancellation.cancel(raising: run?.raising)
            }
        }
        context.cancellation = scope.cancellation
        return try await InterpreterExecutionContext.$current.withValue(context) {
            try await operation(scope)
        }
    }
}
