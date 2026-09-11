//
//  Interpreter+captureOutput.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-24.
//

import Foundation

enum InterpreterExecutionContext {
    typealias Output = @MainActor @Sendable (String) -> Void
    typealias InputHandler = @MainActor @Sendable (String) async throws -> Void

    struct Context {
        var output: Output?
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
        var capturedOutput = ""

        try await InterpreterExecutionContext.withOutput(traceRecorder) {
            try await operation()
        } stdout: { text in
            capturedOutput += text
        }

        return capturedOutput
    }
}
