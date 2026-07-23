//
//  Interpreter+captureOutput.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-24.
//

import Foundation

/// Buffer the temporary `print` callback appends to while
/// ``Interpreter/withOutputCapture(_:)`` runs.
@MainActor
private var capturedOutput = ""

public extension Interpreter {
    /// Runs `operation` while capturing everything Python prints, and returns
    /// the collected text.
    ///
    /// pocketpy routes `print` through a synchronous C callback, so it is
    /// swapped for the duration of `operation` and restored afterwards.
    /// Capturing there is deterministic, unlike the asynchronous stdout relay
    /// that feeds the console.
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
    static func withOutputCapture(_ operation: () async throws -> Void) async rethrows -> String {
        let previousPrint = py.callbacks.print
        let previousBuffer = capturedOutput
        capturedOutput = ""

        py.callbacks.print = { cString in
            guard let cString else { return }
            MainActor.assumeIsolated {
                capturedOutput += String(cString: cString)
            }
        }
        defer {
            py.callbacks.print = previousPrint
            capturedOutput = previousBuffer
        }

        try await operation()
        return capturedOutput
    }
}
