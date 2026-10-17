//
//  Interpreter+captureOutput.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-24.
//

import SwiftUI
import Synchronization

enum InterpreterExecutionContext {
    /// Called on whichever thread runs Python: main for pocketpy, either
    /// main or the Python actor's for CPython.
    typealias Output = @Sendable (String) -> Void
    typealias InputHandler = @MainActor @Sendable (String) async throws -> Void
    typealias Display = @MainActor @Sendable (AnyView) -> Void

    struct Context {
        var output: Output?
        /// Where `display` presents, in place of the interface's.
        var display: Display?
        var inputHandler: InputHandler?
        var traceRecorder: LineTracer?
        var cancellation: RunCancellation?
        /// The context id of the running execution, or `0` outside one.
        var contextId: UInt64 = 0
    }

    @TaskLocal static var current = Context()

    static func withOutput<T>(
        _ traceRecorder: LineTracer? = nil,
        cancellation: RunCancellation? = nil,
        contextId: UInt64 = 0,
        operation: @Sendable () async throws -> T,
        stdout: @escaping Output
    ) async rethrows -> T {
        var context = current
        context.output = stdout
        context.traceRecorder = traceRecorder
        context.cancellation = cancellation
        context.contextId = contextId

        return try await $current.withValue(context) {
            try await operation()
        }
    }
}

public extension Interpreter {
    /// Runs `operation` with a handler invoked before Python requests input.
    static func withInputHandler<T>(
        _ inputHandler: @MainActor @escaping @Sendable (String) async throws -> Void,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        var context = InterpreterExecutionContext.current
        context.inputHandler = inputHandler

        return try await InterpreterExecutionContext.$current.withValue(context) {
            try await operation()
        }
    }

    /// Runs `operation` with what Python prints in it, its awaits included,
    /// sent to `stdout` rather than the run's output. The rest of the run's
    /// context stays, so a stop still reaches it.
    ///
    /// stdout: Called on whichever thread Python prints from.
    @MainActor
    static func withOutput<T>(
        to stdout: @escaping @Sendable (String) -> Void,
        operation: () async throws -> T
    ) async rethrows -> T {
        var context = InterpreterExecutionContext.current
        context.output = stdout
        return try await InterpreterExecutionContext.$current.withValue(context) {
            try await operation()
        }
    }

    /// Runs `operation` with what Python prints sent to `stdout`, and what it
    /// displays sent to `display`, rather than to the console.
    @MainActor
    static func withOutput<T>(
        to stdout: @escaping @Sendable (String) -> Void,
        display: @escaping @MainActor @Sendable (AnyView) -> Void,
        operation: () async throws -> T
    ) async rethrows -> T {
        var context = InterpreterExecutionContext.current
        context.output = stdout
        context.display = display
        return try await InterpreterExecutionContext.$current.withValue(context) {
            try await operation()
        }
    }

    /// Presents a view where the current execution displays: its own place,
    /// or the console.
    @MainActor
    static func display(_ view: AnyView) {
        if let display = InterpreterExecutionContext.current.display {
            display(view)
        } else {
            interface.display(view)
        }
    }

    /// Invokes the input handler installed for the current execution, if any.
    static func prepareForInput(prompt: String) async throws {
        try await InterpreterExecutionContext.current.inputHandler?(prompt)
    }

    /// Runs `operation` while capturing everything Python prints, and returns
    /// the collected text.
    ///
    /// pocketpy routes `print` through a synchronous C callback. The shared
    /// callback checks a task-local output sink first, so this capture stays
    /// scoped to `operation` without replacing global callback state.
    ///
    /// ```swift
    /// let code = try Interpreter.compile("print('hi')")
    /// let output = await Interpreter.withOutputCapture {
    ///     try? await Interpreter.execute(code)
    /// }
    /// ```
    ///
    /// Nested calls are supported: each returns only the text printed within
    /// its own scope, and the enclosing capture resumes afterwards.
    ///
    /// - Parameters:
    ///   - traceRecorder: Optional line tracer scoped to the operation.
    ///   - operation: The work whose `print` output should be captured.
    /// - Returns: The concatenated text passed to `print` during `operation`.
    static func withOutputCapture(
        _ traceRecorder: LineTracer? = nil,
        operation: @Sendable () async throws -> Void
    ) async rethrows -> String {
        let captured = Mutex("")

        try await InterpreterExecutionContext.withOutput(traceRecorder) {
            try await operation()
        } stdout: { text in
            captured.withLock { $0 += text }
        }

        return captured.withLock { $0 }
    }
}
