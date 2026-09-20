//
//  ViewRepresentationTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-05.
//

import Testing
import SwiftPy
import SwiftUI

@Scriptable(base: .View)
class CustomView {
    func body() -> AnyView {
        AnyView(Text("content"))
    }
}

@MainActor
@Suite(.serialized)
struct ViewRepresentationTests {
    @Test
    func customView() async {
        let main = py.main

        var displayed: AnyView?
        Interpreter.interface.display = { displayed = $0 }
        defer { Interpreter.interface = InterpreterInterface() }

        _ = AnyView.pyType
        _ = CustomView.pyType

        let customView = CustomView()
        main.custom_view = customView

        await Interpreter.run("custom_view", mode: .single)

        #expect(displayed != nil)
    }

    @Test
    func displayBinding() async {
        let main = py.main

        var displayed: AnyView?
        Interpreter.interface.display = { displayed = $0 }
        defer { Interpreter.interface = InterpreterInterface() }

        _ = AnyView.pyType
        _ = CustomView.pyType

        main.display_view = CustomView()

        await Interpreter.run("""
        from interpreter import display
        display(display_view)
        """)

        #expect(displayed != nil)
    }

    #if cpython
    /// A Python subclass keeps state of its own; writing it must reach the
    /// box the SwiftUI side observes, and a Swift-backed view has no box.
    @Test
    func pythonSubclassWritesInvalidateItsState() async throws {
        let main = py.main
        // Made on the Swift side: the macro binds no __init__ for a class
        // without one, so CustomView() from Python would carry no value.
        main.inner = CustomView()
        main.plain = CustomView()

        await Interpreter.run("""
        class Counter(View):
            def __init__(self):
                super().__init__()
                self.count = 0
            def body(self):
                return inner
        counter = Counter()
        """)

        let counter: PyObject = try #require(main.counter)
        #expect(counter.reference.view != nil)
        #expect(Interpreter.evaluate("counter._view_state.revision") == 0)

        await Interpreter.run("counter.count += 1")
        #expect(Interpreter.evaluate("counter._view_state.revision") == 1)
        #expect(Interpreter.evaluate("counter.count") == 1)

        // The same box on the next render, not a fresh one.
        #expect(counter.reference.view != nil)
        #expect(Interpreter.evaluate("counter._view_state.revision") == 1)

        let plain: PyObject = try #require(main.plain)
        #expect(plain.reference.view != nil)
        #expect(Interpreter.evaluate("hasattr(plain, '_view_state')") == false)
    }
    #endif
}
