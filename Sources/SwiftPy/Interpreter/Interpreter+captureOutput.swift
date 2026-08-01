//
//  Interpreter+captureOutput.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-24.
//

import Foundation

enum InterpreterExecutionContext {
    typealias Output = @MainActor @Sendable (String) -> Void

    @TaskLocal static var output: Output?

    static func withOutput<T>(
        _ output: @escaping Output,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await $output.withValue(output) {
            try await operation()
        }
    }
}

public extension Interpreter {
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
    /// - Parameter operation: The work whose `print` output should be captured.
    /// - Returns: The concatenated text passed to `print` during `operation`.
    static func withOutputCapture(_ operation: @Sendable () async throws -> Void) async rethrows -> String {
        var capturedOutput = ""

        try await InterpreterExecutionContext.withOutput({ text in
            capturedOutput += text
        }) {
            try await operation()
        }

        return capturedOutput
    }
}
