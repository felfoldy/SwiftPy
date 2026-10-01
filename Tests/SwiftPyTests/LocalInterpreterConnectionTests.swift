//
//  LocalInterpreterConnectionTests.swift
//  SwiftPy
//

import Testing
import Foundation
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct LocalInterpreterConnectionTests {

    // MARK: - complete

    @Test func completeEmitsCompletionsWithToken() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        let token = UUID()
        await connection.perform(.complete(token: token, lastComponent: ""))

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        guard case let .completions(_, resultToken) = event?.payload else {
            Issue.record("Expected .completions payload")
            return
        }
        #expect(resultToken == token)
    }

    // MARK: - execute

    @Test func executeEmitsStartedWithTokenAndContextId() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        let token = UUID()
        await connection.perform(.execute(token: token, source: "1 + 1"))

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        guard case let .started(resultToken) = event?.payload else {
            Issue.record("Expected .started payload")
            return
        }
        #expect(resultToken == token)
        #expect(event?.id == 1)
    }

    // MARK: - compile

    @Test func compileInvalidCodeEmitsFailureAttachment() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events
        await connection.compile(id: 1, source: "def f(")

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // stderr (compile error traceback)
        let event = await iterator.next()

        guard case let .attachment(items) = event?.payload else {
            Issue.record("Expected .attachment payload")
            return
        }
        #expect(items.contains(.image(name: "xmark.square")))
    }

    @Test func staleCompileIdIsIgnored() async {
        let connection = LocalInterpreterConnection()

        await connection.compile(id: 2, source: "_test_stale = 1")
        await connection.compile(id: 1, source: "_test_stale = 2") // stale, id < latestCompileId
        await connection.run(id: 2)

        // The stale id=1 compile was dropped, so the id=2 code ran.
        #expect(Interpreter.evaluate("_test_stale") == 1)
    }

    // MARK: - run

    @Test func runWithMatchingIdExecutesCompiledCode() async {
        let connection = LocalInterpreterConnection()

        await connection.compile(id: 1, source: "_test_run_x = 42")
        await connection.run(id: 1)

        let result: Int? = Interpreter.evaluate("_test_run_x")
        #expect(result == 42)
    }

    @Test func runTagsPrintOutputWithContextId() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.compile(id: 1, source: "print('tagged stdout')")

        var iterator = stream.makeAsyncIterator()

        await connection.run(id: 1)

        var taggedStdout: InterpreterEvent?
        for _ in 0..<2 {
            guard let event = await iterator.next() else { break }
            if case let .stdout(text) = event.payload, event.id == 1, text.contains("tagged stdout") {
                taggedStdout = event
                break
            }
        }

        #expect(taggedStdout != nil)
    }

    @Test func runWithNonMatchingIdDoesNotExecute() async {
        let connection = LocalInterpreterConnection()

        await connection.compile(id: 1, source: "_test_no_run_y = 99")
        await connection.run(id: 2) // id mismatch — should not execute

        let result: Int? = Interpreter.evaluate("_test_no_run_y")
        #expect(result == nil)
    }

    // MARK: - script names

    /// Runs `source` as `name` and returns the events up to the run's end.
    private func execute(
        _ source: String,
        name: String? = nil,
        on connection: LocalInterpreterConnection
    ) async -> (id: UInt64, events: [InterpreterEvent]) {
        var iterator = await connection.events.makeAsyncIterator()
        await connection.perform(.execute(token: UUID(), source: source, name: name))
        var id: UInt64 = 0
        var events: [InterpreterEvent] = []
        while let event = await iterator.next() {
            events.append(event)
            if case .started = event.payload { id = event.id }
            if case .attachment = event.payload, event.id == id { break }
        }
        return (id, events)
    }

    private func feedback(in events: [InterpreterEvent], for id: UInt64) -> [ExecutionFeedback] {
        events.compactMap { event in
            if case let .feedback(item) = event.payload, event.id == id { item } else { nil }
        }
    }

    @Test func aNamedRunsTracebackShowsItsName() async {
        let connection = LocalInterpreterConnection()

        let run = await execute("x = 1\n1 / 0", name: "<script:2>", on: connection)

        let stderr = run.events.compactMap { if case let .stderr(text) = $0.payload { text.replacing(/\u{1B}\[[0-9;]*m/, with: "") } else { nil } }
        #expect(stderr.contains { $0.contains(#"File "<script:2>", line 2"#) })
        #expect(feedback(in: run.events, for: run.id).contains(ExecutionFeedback(lineNumber: 2, type: .error)))
    }

    @Test func anUnnamedRunIsNamedByItsId() async {
        let connection = LocalInterpreterConnection()

        let run = await execute("1 / 0", on: connection)

        let stderr = run.events.compactMap { if case let .stderr(text) = $0.payload { text.replacing(/\u{1B}\[[0-9;]*m/, with: "") } else { nil } }
        #expect(stderr.contains { $0.contains(#"File "<script>/\#(run.id)""#) })
    }

    // Without line tracing: the line is read off the stack as it prints.
    @Test func outputFlashesTheScriptThatPrinted() async {
        let connection = LocalInterpreterConnection()

        let definition = await execute(
            "def _test_named_print():\n    print('hi')",
            name: "<script:1>", on: connection
        )
        let call = await execute("_test_named_print()", name: "<script:3>", on: connection)

        #expect(feedback(in: call.events, for: definition.id).contains(ExecutionFeedback(lineNumber: 2, type: .output)))
    }

    @Test func anErrorInAnotherScriptFlagsTheCallingLine() async {
        let connection = LocalInterpreterConnection()

        _ = await execute("def _test_named_fail():\n    1 / 0", name: "<script:1>", on: connection)
        let call = await execute("y = 0\n_test_named_fail()", name: "<script:4>", on: connection)

        #expect(feedback(in: call.events, for: call.id).contains(ExecutionFeedback(lineNumber: 2, type: .error)))
    }

    // MARK: - check

#if mypy
    private func check(_ source: String, after prelude: String = "") async -> [Diagnostic] {
        let connection = LocalInterpreterConnection()
        var iterator = await connection.events.makeAsyncIterator()
        let token = UUID()
        await connection.perform(.check(token: token, source: source, prelude: prelude))
        while let event = await iterator.next() {
            if case let .diagnostics(items, eventToken) = event.payload, eventToken == token { return items }
        }
        return []
    }

    @Test func checkReportsATypeErrorWhereItIs() async {
        let items = await check("x: str = 1")
        #expect(items == [Diagnostic(
            line: 1, column: 10, endLine: 1, endColumn: 11, severity: .error,
            message: #"Incompatible types in assignment (expression has type "int", variable has type "str")"#,
            code: "assignment"
        )])
    }

    @Test func checkKnowsThePreludeButReportsOnlyTheSource() async {
        let items = await check("y = known + 1\nbad: int = 'a'", after: "known = 1\nwrong: str = 2")
        #expect(items.map(\.line) == [2])
    }

    @Test func checkAllowsWhatCardsDo() async {
        let items = await check("import asyncio\nimport some_swift_module\nawait asyncio.sleep(0)\nn = 'a'", after: "n = 1")
        #expect(items.isEmpty)
    }
#endif

    // MARK: - stop

    @Test func stopCancelsRunningExecutionAndEmitsStopped() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.compile(id: 1, source: """
        import asyncio
        _test_stop_flag = False
        await asyncio.sleep(2)
        _test_stop_flag = True
        """)

        var iterator = stream.makeAsyncIterator()

        // Start the run; it suspends on the awaited sleep and yields the actor.
        let runTask = Task { await connection.run(id: 1) }
        try? await Task.sleep(for: .milliseconds(50))

        await connection.perform(.stop(id: 1))
        await runTask.value

        var stopped = false
        while let event = await iterator.next() {
            if case .stopped = event.payload, event.id == 1 {
                stopped = true
                break
            }
        }

        #expect(stopped)
        // The continuation after the awaited sleep must not have run.
        #expect(Interpreter.evaluate("_test_stop_flag") == false)
    }

    @Test func stopCancelsAllConcurrentlyAwaitedTasks() async {
        let connection = LocalInterpreterConnection()

        // Two tasks awaited concurrently: a single-slot handler would only
        // cancel one of them, so the continuation would still run.
        await connection.compile(id: 1, source: """
        import asyncio

        _test_gather_flag = False

        async def _test_gather_wait():
            await asyncio.sleep(2)

        await asyncio.gather(_test_gather_wait(), _test_gather_wait())
        _test_gather_flag = True
        """)

        let runTask = Task { await connection.run(id: 1) }
        // A stop before the run registers itself has nothing to cancel, so
        // wait until the code has reached its await.
        for _ in 0..<200 where (Interpreter.evaluate("_test_gather_flag") as Bool?) == nil {
            try? await Task.sleep(for: .milliseconds(10))
        }

        await connection.perform(.stop(id: 1))
        await runTask.value

        #expect(Interpreter.evaluate("_test_gather_flag") == false)
    }

#if cpython
    @Test func stopInterruptsSynchronousCode() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.compile(id: 1, source: """
        import time
        _test_interrupt_flag = 'running'
        try:
            while True:
                pass
        finally:
            _test_interrupt_flag = 'unwound'
        """)

        var iterator = stream.makeAsyncIterator()
        let runTask = Task { await connection.run(id: 1) }
        for _ in 0..<200 where (Interpreter.evaluate("_test_interrupt_flag") as String?) != "running" {
            try? await Task.sleep(for: .milliseconds(10))
        }

        // The stop reaches the loop, not the cell queued behind it.
        await connection.compile(id: 2, source: "_test_interrupt_flag = 'next'")
        let nextTask = Task { await connection.run(id: 2) }
        try? await Task.sleep(for: .milliseconds(20))
        await connection.perform(.stop(id: 2))
        await connection.perform(.stop(id: 1))
        await runTask.value
        await nextTask.value

        var stopped = false
        while let event = await iterator.next() {
            if case .stopped = event.payload, event.id == 1 {
                stopped = true
                break
            }
        }
        #expect(stopped)
        #expect(Interpreter.evaluate("_test_interrupt_flag") == "next")
    }
#endif

    @Test func stopWithUnknownIdDoesNotEmitStopped() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.perform(.stop(id: 999)) // nothing running
        let token = UUID()
        await connection.perform(.execute(token: token, source: "1 + 1"))

        // The first event should be the execute's `started`, not a `.stopped`.
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()
        guard case .started = event?.payload else {
            Issue.record("Expected .started, stop on an unknown id should emit nothing")
            return
        }
    }
}
