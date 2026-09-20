//
//  TraceTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-06.
//

import Testing
import Synchronization
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct TraceTests {
    /// Records the events delivered to a trace function for later assertions.
    /// Nonisolated with a lock: CPython traces on the Python thread.
    nonisolated final class Recorder: Sendable {
        struct Entry: Sendable {
            let event: PyAPI.TraceEvent
            let line: Int?
            let source: String?
        }

        private let storage = Mutex<[Entry]>([])

        var entries: [Entry] {
            get { storage.withLock { $0 } }
            set { storage.withLock { $0 = newValue } }
        }

        /// Line numbers of `.line` events from `source`, in delivery order.
        func lines(inSource source: String) -> [Int] {
            entries.compactMap {
                $0.event == .line && $0.source == source ? $0.line : nil
            }
        }

        /// Only the cell's own frames: on CPython, compiling runs Python
        /// helpers of its own under the same trace.
        func count(of event: PyAPI.TraceEvent, inSource source: String) -> Int {
            entries.filter { $0.event == event && $0.source == source }.count
        }

        func record(_ frame: PyAPI.Frame, _ event: PyAPI.TraceEvent) {
            let entry = Entry(event: event,
                              line: frame.lineNumber,
                              source: frame.sourceLocation)
            storage.withLock { $0.append(entry) }
        }
    }

    @Test func lineEventsReportSourceLinesInOrder() async {
        let recorder = Recorder()
        py.setTrace(recorder.record)
        defer { py.setTrace(nil) }

        await Interpreter.run("""
        x = 10
        y = 20
        z = x + y
        """, filename: "<trace>", mode: .execution)

        #expect(recorder.lines(inSource: "<trace>") == [1, 2, 3])
    }

    @Test func lineEventsReportSourceFilename() async {
        let recorder = Recorder()
        py.setTrace(recorder.record)
        defer { py.setTrace(nil) }

        await Interpreter.run("value = 1", filename: "<named>", mode: .execution)

        #expect(recorder.lines(inSource: "<named>") == [1])
    }

    @Test func pushAndPopAreBalancedAcrossCalls() async {
        let recorder = Recorder()
        py.setTrace(recorder.record)
        defer { py.setTrace(nil) }

        await Interpreter.run("""
        def foo():
            return 42

        foo()
        """, filename: "<trace>", mode: .execution)

        // The module frame plus the `foo` call frame both push and pop.
        #expect(recorder.count(of: .push, inSource: "<trace>") == 2)
        #expect(recorder.count(of: .pop, inSource: "<trace>") == 2)
    }

    @Test func setTraceNilRemovesTheHook() async {
        let recorder = Recorder()
        py.setTrace(recorder.record)

        await Interpreter.run("first = 1", filename: "<trace>", mode: .execution)
        #expect(!recorder.entries.isEmpty)

        py.setTrace(nil)
        recorder.entries.removeAll()

        await Interpreter.run("second = 2", filename: "<trace>", mode: .execution)
        #expect(recorder.entries.isEmpty)
    }

    @Test func replacingTraceUsesTheNewFunction() async {
        let first = Recorder()
        let second = Recorder()

        py.setTrace(first.record)
        py.setTrace(second.record)
        defer { py.setTrace(nil) }

        await Interpreter.run("only = 1", filename: "<trace>", mode: .execution)

        #expect(first.entries.isEmpty)
        #expect(!second.entries.isEmpty)
    }

    @Test func lineTracerRecordsScriptContext() async throws {
        let tracer = LineTracer()
        Interpreter.enableTrace()
        defer { Interpreter.disableTrace() }

        let code = try Interpreter.compile(
            "first = 1\nsecond = 2",
            filename: "<script>/42"
        )
        _ = try await Interpreter.withOutputCapture(tracer) {
            try await Interpreter.execute(code)
        }

        #expect(tracer.entries.map(\.lineNumber) == [1, 2])
        #expect(tracer.entries.allSatisfy { $0.contextId == 42 })
        #expect(tracer.lastLine(forContext: 42) == 2)
    }
}
