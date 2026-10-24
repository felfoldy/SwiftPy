//
//  AsyncInputTests.swift
//  SwiftPy
//

import Foundation
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
        var asked: InputRequest?
        Interpreter.interface.requestInput = { request in
            asked = request
            return InputResponse(text: "Ada")
        }

        await Interpreter.run("""
        from interpreter import ainput
        _answer = await ainput("Name?")
        _blank = await ainput()
        """)

        #expect(Interpreter.evaluate("_answer") == "Ada")
        #expect(asked == InputRequest(prompt: ""))
        #expect(Interpreter.evaluate("_blank") == "Ada")
    }

    @Test func inputWaitsForTheSameRequest() async {
        defer { restore() }
        var asked: InputRequest?
        Interpreter.interface.requestInput = { request in
            asked = request
            return InputResponse(text: "Bob")
        }

        await Interpreter.run("_typed = input('Who?')")

        #expect(Interpreter.evaluate("_typed") == "Bob")
        #expect(asked == InputRequest(prompt: "Who?"))
    }

    @Test func otherWorkRunsWhileItWaits() async throws {
        defer { restore() }
        Interpreter.interface.requestInput = { _ in
            try await Task.sleep(for: .milliseconds(200))
            return InputResponse(text: "done")
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

    @Test func asksForImagesAndLinesByKeyword() async {
        defer { restore() }
        var asked: [InputRequest] = []
        Interpreter.interface.requestInput = { request in
            asked.append(request)
            return InputResponse(text: "look", images: [Data([1, 2])])
        }

        await Interpreter.run("""
        import sys, types
        from interpreter import ainput, InputResult
        # A stand-in for views, which SwiftPy itself doesn't have.
        _views = types.ModuleType("views")
        _views.Image = lambda data: ("image", data)
        sys.modules["views"] = _views
        try:
            _answer = await ainput("See?", images=True)
            _lines = input("Notes?", multiline=True)
        finally:
            del sys.modules["views"]
        _is_result = isinstance(_answer, InputResult) and isinstance(_answer, str)
        """)

        #expect(asked == [
            InputRequest(prompt: "See?", acceptsImages: true),
            InputRequest(prompt: "Notes?", isMultiline: true),
        ])
        #expect(Interpreter.evaluate("_answer") == "look")
        #expect(Interpreter.evaluate("_is_result") == true)
        #expect(Interpreter.evaluate("str(_answer.images)") == "[('image', b'\\x01\\x02')]")
    }

    @Test func aRunWithItsOwnPlaceAsksThereAndSoDoItsCallbacks() async throws {
        defer { restore() }
        var askedHere = false
        Interpreter.interface.requestInput = { _ in
            askedHere = true
            return InputResponse(text: "console")
        }
        var asked: [String] = []
        var route: Interpreter.OutputRoute?

        await Interpreter.withInput({ request in
            asked.append(request.prompt)
            return InputResponse(text: "own")
        }, secret: { _ in "" }) {
            await Interpreter.withOutput(to: { _ in }, display: { _ in }) {
                route = Interpreter.outputRoute
                await Interpreter.run("_own = input('Here?')")
            }
        }
        #expect(Interpreter.evaluate("_own") == "own")

        // A callback the run set up asks where the run did.
        await Interpreter.withOutputRoute(route) {
            Task { await Interpreter.run("_later = input('Later?')") }
        }.value
        #expect(Interpreter.evaluate("_later") == "own")
        #expect(asked == ["Here?", "Later?"])
        #expect(!askedHere)
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
