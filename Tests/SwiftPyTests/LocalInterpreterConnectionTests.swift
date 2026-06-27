//
//  LocalInterpreterConnectionTests.swift
//  SwiftPy
//

import Testing
@testable import SwiftPy

@MainActor
struct LocalInterpreterConnectionTests {

    // MARK: - createContext

    @Test func createContextEmitsContextCreatedEvent() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events
        await connection.perform(.createContext)

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        guard case .contextCreated = event?.payload else {
            Issue.record("Expected .contextCreated payload")
            return
        }
        #expect(event?.id == 1)
    }

    @Test func createContextIncrementsContextId() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.perform(.createContext)
        await connection.perform(.createContext)

        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        let second = await iterator.next()

        #expect(first?.id == 1)
        #expect(second?.id == 2)
    }

    // MARK: - complete

    @Test func completeWithMatchingContextIdEmitsCompletions() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.perform(.createContext)
        await connection.perform(.complete(id: 1, lastComponent: ""))

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // contextCreated
        let event = await iterator.next()

        guard case .completions = event?.payload else {
            Issue.record("Expected .completions payload")
            return
        }
        #expect(event?.id == 1)
    }

    // MARK: - compile

    @Test func compileValidCodeEmitsExecutable() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events
        await connection.perform(.compile(id: 1, source: "1 + 1"))

        var iterator = stream.makeAsyncIterator()

        let inputEvent = await iterator.next()
        guard case .inputSource(let text) = inputEvent?.payload else {
            Issue.record("Expected .inputSource payload")
            return
        }
        #expect(text == "1 + 1")

        let event = await iterator.next()
        guard case .isExecutable(let value) = event?.payload else {
            Issue.record("Expected .isExecutable payload")
            return
        }
        #expect(value == true)
        #expect(event?.id == 1)
    }

    @Test func compileIncompleteCodeEmitsNotExecutable() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events
        await connection.perform(.compile(id: 1, source: "def f("))

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // inputSource
        let event = await iterator.next()

        guard case .isExecutable(let value) = event?.payload else {
            Issue.record("Expected .isExecutable event")
            return
        }
        #expect(value == false)
    }

    @Test func staleCompileIdIsIgnored() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.perform(.compile(id: 2, source: "a = 1"))
        await connection.perform(.compile(id: 1, source: "b = 2")) // stale, id < latestCompileId

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        // Only the id=2 compile should have emitted an event
        #expect(event?.id == 2)
    }

    // MARK: - run

    @Test func runWithMatchingIdExecutesCompiledCode() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.perform(.compile(id: 1, source: "_test_run_x = 42"))

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // inputSource
        let executableEvent = await iterator.next()

        guard case .isExecutable(let isExec) = executableEvent?.payload, isExec else {
            Issue.record("Code should be executable before running")
            return
        }

        await connection.perform(.run(id: 1))

        let result: Int? = Interpreter.evaluate("_test_run_x")
        #expect(result == 42)
    }

    @Test func runWithNonMatchingIdDoesNotExecute() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.perform(.compile(id: 1, source: "_test_no_run_y = 99"))

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // isExecutable

        await connection.perform(.run(id: 2)) // id mismatch — should not execute

        let result: Int? = Interpreter.evaluate("_test_no_run_y")
        #expect(result == nil)
    }
}
