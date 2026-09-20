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
