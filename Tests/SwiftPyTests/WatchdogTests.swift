//
//  WatchdogTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-06.
//

import Testing
@testable import SwiftPy

@MainActor
struct WatchdogTests {
    /// Arms the watchdog for one second, then runs an infinite loop and
    /// verifies the interpreter aborts it with a `TimeoutError` after roughly
    /// that long.
    @Test func watchdogAbortsRunawayLoop() {
        py.beginWatchdog(milliseconds: 1000)
        defer { py.endWatchdog() }

        let clock = ContinuousClock()
        let start = clock.now

        let error = #expect(throws: PythonError.self) {
            try py.exec(source: """
            while 1:
                pass
            """, filename: "<watchdog>", mode: .execution, module: py.main.reference)
        }

        let elapsed = clock.now - start

        #expect(error.map { py.tpname($0.type) } == "TimeoutError")
        #expect(elapsed >= .milliseconds(900))
        #expect(elapsed < .seconds(10))
    }
}
