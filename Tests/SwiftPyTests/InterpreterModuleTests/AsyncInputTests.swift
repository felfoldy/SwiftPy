//
//  AsyncInputTests.swift
//  SwiftPy
//

import Testing
@testable import SwiftPy

@Suite("input and interpreter.ainput", .serialized)
@MainActor
struct AsyncInputTests {
    private func restore() {
        // Only this field: the interface is global, shared with other suites.
        Interpreter.interface.requestInput = InterpreterInterface().requestInput
    }

    @Test func asksTheHost() async {
        defer { restore() }
        var asked: String?
        Interpreter.interface.requestInput = { prompt in
            asked = prompt
            return "Ada"
        }

        await Interpreter.run("""
        from interpreter import ainput
        _answer = await ainput("Name?")
        _blank = await ainput()
        """)

        #expect(Interpreter.evaluate("_answer") == "Ada")
        #expect(asked == "")
        #expect(Interpreter.evaluate("_blank") == "Ada")
    }

    @Test func inputWaitsForTheSameRequest() async {
        defer { restore() }
        var asked: String?
        Interpreter.interface.requestInput = { prompt in
            asked = prompt
            return "Bob"
        }

        await Interpreter.run("_typed = input('Who?')")

        #expect(Interpreter.evaluate("_typed") == "Bob")
        #expect(asked == "Who?")
    }

    @Test func otherWorkRunsWhileItWaits() async throws {
        defer { restore() }
        Interpreter.interface.requestInput = { _ in
            try await Task.sleep(for: .milliseconds(200))
            return "done"
        }

        await Interpreter.run("""
        import asyncio
        from interpreter import ainput

        _ticks = 0
        async def _tick():
            global _ticks
            while True:
                _ticks += 1
                await asyncio.sleep(0.01)

        _ticker = asyncio.ensure_future(_tick())
        _answer = await ainput("Wait")
        _ticker.cancel()
        """)

        #expect(Interpreter.evaluate("_answer") == "done")
        let ticks: Int = try #require(Interpreter.evaluate("_ticks"))
        #expect(ticks > 3)
    }

    @Test func aHostThatCantAskRaises() async {
        restore()
        await Interpreter.run("""
        from interpreter import ainput
        try:
            await ainput("Name?")
            _raised = None
        except RuntimeError as error:
            _raised = str(error)
        """)
        #expect(Interpreter.evaluate("_raised") == "Nothing here can ask for input.")
    }
}
