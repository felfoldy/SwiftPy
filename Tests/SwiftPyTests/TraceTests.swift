//
//  TraceTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-06.
//

import Testing
@testable import SwiftPy

@MainActor
struct TraceTests {
    /// Records the events delivered to a trace function for later assertions.
    @MainActor
    final class Recorder {
        struct Entry {
            let event: PyAPI.TraceEvent
            let line: Int?
            let source: String?
        }

        var entries: [Entry] = []

        /// Line numbers of `.line` events from `source`, in delivery order.
        func lines(inSource source: String) -> [Int] {
            entries.compactMap {
                $0.event == .line && $0.source == source ? $0.line : nil
            }
        }

        func count(of event: PyAPI.TraceEvent) -> Int {
            entries.filter { $0.event == event }.count
        }

        func record(_ frame: PyAPI.Frame, _ event: PyAPI.TraceEvent) {
            entries.append(Entry(event: event,
                                 line: frame.lineNumber,
                                 source: frame.sourceLocation))
        }
    }

    @Test func lineEventsReportSourceLinesInOrder() {
        let recorder = Recorder()
        py.setTrace(recorder.record)
        defer { py.setTrace(nil) }

        Interpreter.run("""
        x = 10
        y = 20
        z = x + y
        """, filename: "<trace>", mode: .execution)

        #expect(recorder.lines(inSource: "<trace>") == [1, 2, 3])
    }

    @Test func lineEventsReportSourceFilename() {
        let recorder = Recorder()
        py.setTrace(recorder.record)
        defer { py.setTrace(nil) }

        Interpreter.run("value = 1", filename: "<named>", mode: .execution)

        let lineEntries = recorder.entries.filter { $0.event == .line }
        #expect(!lineEntries.isEmpty)
        #expect(lineEntries.allSatisfy { $0.source == "<named>" })
    }

    @Test func pushAndPopAreBalancedAcrossCalls() {
        let recorder = Recorder()
        py.setTrace(recorder.record)
        defer { py.setTrace(nil) }

        Interpreter.run("""
        def foo():
            return 42

        foo()
        """, filename: "<trace>", mode: .execution)

        // The module frame plus the `foo` call frame both push and pop.
        #expect(recorder.count(of: .push) == 2)
        #expect(recorder.count(of: .push) == recorder.count(of: .pop))
    }

    @Test func setTraceNilRemovesTheHook() {
        let recorder = Recorder()
        py.setTrace(recorder.record)

        Interpreter.run("first = 1", filename: "<trace>", mode: .execution)
        #expect(!recorder.entries.isEmpty)

        py.setTrace(nil)
        recorder.entries.removeAll()

        Interpreter.run("second = 2", filename: "<trace>", mode: .execution)
        #expect(recorder.entries.isEmpty)
    }

    @Test func replacingTraceUsesTheNewFunction() {
        let first = Recorder()
        let second = Recorder()

        py.setTrace(first.record)
        py.setTrace(second.record)
        defer { py.setTrace(nil) }

        Interpreter.run("only = 1", filename: "<trace>", mode: .execution)

        #expect(first.entries.isEmpty)
        #expect(!second.entries.isEmpty)
    }
}
