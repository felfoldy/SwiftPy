//
//  WatchdogTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-06.
//

import Testing
@testable import SwiftPy

// The watchdog is pocketpy's. Under the cpython trait PyEval_EvalCode runs the
// runaway loop with nothing to stop it, which hangs the whole suite.
#if !cpython

@MainActor
@Suite(.serialized)
struct WatchdogTests {
    /// Executing through the interpreter aborts a runaway loop with a
    /// `TimeoutError` instead of hanging.
    @Test func interpreterAbortsRunawayLoop() async throws {
        Interpreter.timeout = 10
        defer { Interpreter.timeout = 1000 }

        let code = try Interpreter.compile("""
        while 1:
            pass
        """, mode: .execution)

        let error = await #expect(throws: PythonError.self) {
            try await Interpreter.execute(code)
        }

        #expect(error.map { py.tpname($0.type) } == "TimeoutError")
    }
}

#endif
