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

    // MARK: - compile

    @Test func compileValidCodeEmitsCompletionsThenExecutable() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events
        await connection.perform(.compile(id: 1, source: "1 + 1"))

        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        let second = await iterator.next()

        guard case .completions = first?.payload else {
            Issue.record("Expected .completions as first event")
            return
        }
        guard case .isExecutable(let value) = second?.payload else {
            Issue.record("Expected .isExecutable as second event")
            return
        }
        #expect(value == true)
        #expect(first?.id == 1)
        #expect(second?.id == 1)
    }

    @Test func compileIncompleteCodeEmitsNotExecutable() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events
        await connection.perform(.compile(id: 1, source: "def f("))

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // completions
        let second = await iterator.next()

        guard case .isExecutable(let value) = second?.payload else {
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
        let first = await iterator.next()
        let second = await iterator.next()

        // Only the id=2 compile should have emitted events
        #expect(first?.id == 2)
        #expect(second?.id == 2)
    }

    // MARK: - run

    @Test func runWithMatchingIdExecutesCompiledCode() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.perform(.compile(id: 1, source: "_test_run_x = 42"))

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // completions
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
        _ = await iterator.next() // completions
        _ = await iterator.next() // isExecutable

        await connection.perform(.run(id: 2)) // id mismatch — should not execute

        let result: Int? = Interpreter.evaluate("_test_no_run_y")
        #expect(result == nil)
    }
}
