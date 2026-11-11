//
//  PlaygroundRunTests.swift
//  SwiftPy
//

import Testing
import Foundation
@testable import SwiftPy

#if cpython
@MainActor
@Suite(.serialized)
struct PlaygroundRunTests {
    struct Run {
        var id: UInt64 = 0
        var events: [InterpreterEvent] = []

        var records: [PlaygroundRecord] {
            events.compactMap { if case let .record(item) = $0.payload, $0.id == id { item } else { nil } }
        }
        var statements: [PlaygroundStatement] {
            events.compactMap { if case let .statements(items) = $0.payload, $0.id == id { items } else { nil } }.first ?? []
        }
        var feedback: [ExecutionFeedback] {
            events.compactMap { if case let .feedback(item) = $0.payload, $0.id == id { item } else { nil } }
        }
        var stopped: Bool {
            events.contains { if case .stopped = $0.payload { $0.id == id } else { false } }
        }
        func last(_ line: Int, _ name: String? = nil) -> PlaygroundRecord? {
            records.last { $0.line == line && $0.name == name }
        }
    }

    private func play(_ source: String, timeout: Double? = 5) async -> Run {
        let connection = LocalInterpreterConnection()
        var iterator = await connection.events.makeAsyncIterator()
        await connection.perform(.execute(
            token: UUID(), source: source, name: "<script playground>",
            namespace: "playground-tests", mode: .playground(timeout: timeout)
        ))
        Interpreter.removeNamespace("playground-tests")
        var run = Run()
        while let event = await iterator.next() {
            run.events.append(event)
            if case .started = event.payload { run.id = event.id }
            guard event.id == run.id else { continue }
            if case .attachment = event.payload { break }
            if case .stopped = event.payload { break }
        }
        return run
    }

    @Test func recordsExpressionsAndAssignments() async {
        let run = await play("""
        class Box:
            pass
        box = Box()
        x = 2
        x += 3
        box.size = x * 10
        x * 3
        """)
        #expect(run.last(4, "x")?.text == "2")
        #expect(run.last(5, "x")?.text == "5")
        #expect(run.last(6, "box.size")?.text == "50")
        #expect(run.last(7)?.text == "15")
        #expect(run.last(7)?.typeName == "int")
    }

    @Test func aLoopCountsItsLine() async {
        let run = await play("""
        total = 0
        for i in range(30):
            total += i
        """)
        let last = run.last(3, "total")
        #expect(last?.count == 30)
        #expect(last?.text == "435")
        // Only the first ones are sent one by one, then the last.
        #expect(run.records.filter { $0.line == 3 }.count < 30)
    }

    @Test func groupsTopLevelStatements() async {
        let run = await play("""
        import math

        @staticmethod
        def area(r: float) -> float:
            return math.pi * r * r

        area(2)
        """)
        #expect(run.statements == [
            PlaygroundStatement(firstLine: 1, lastLine: 1),
            PlaygroundStatement(firstLine: 3, lastLine: 5),
            PlaygroundStatement(firstLine: 7, lastLine: 7),
        ])
    }

    @Test func printFlashesItsLine() async {
        let run = await play("x = 1\nprint('hi')")
        #expect(run.feedback.contains(ExecutionFeedback(lineNumber: 2, type: .output)))
        let stdout = run.events.compactMap { if case let .stdout(text) = $0.payload { text } else { nil } }.joined()
        #expect(stdout == "hi\n")
        // print's None isn't a value.
        #expect(run.last(2) == nil)
    }

    @Test func anErrorIsReportedAtItsLine() async {
        let run = await play("x = 1\ny = x / 0\nz = 3")
        #expect(run.feedback.contains(ExecutionFeedback(lineNumber: 2, type: .error)))
        #expect(run.last(3, "z") == nil)
    }

    @Test func aSyntaxErrorIsReportedAtItsLine() async {
        let run = await play("x = 1\ny = (\n")
        #expect(run.feedback.contains { $0.type == .error })
        #expect(run.statements.isEmpty)
    }

    @Test func topLevelAwaitRuns() async {
        let run = await play("import asyncio\nawait asyncio.sleep(0.01)\nx = 4")
        #expect(run.last(3, "x")?.text == "4")
    }

    @Test func theTimeoutStopsALoop() async {
        let run = await play("while True:\n    pass", timeout: 0.5)
        #expect(run.stopped)
    }

    @Test func aDocstringIsNoValue() async {
        let run = await play("\"\"\"A module.\"\"\"\ndef f():\n    \"Doc.\"\n    return 1\nf()")
        #expect(run.last(1) == nil)
        #expect(run.last(3) == nil)
        #expect(run.last(5)?.text == "1")
    }
}
#endif
