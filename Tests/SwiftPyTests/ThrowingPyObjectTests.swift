//
//  ThrowingPyObjectTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-13.
//

import Testing
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct ThrowingPyObjectTests {
    init() async {
        await Interpreter.run("""
        import math
        class Box:
            value = 3
            none = None
            def scaled(self, by, tag): return f"{tag}{self.value * by}"
            def child(self): return Box()
        box = Box()
        """)
    }

    @Test func chainsAttributesAndCalls() throws {
        let main = py.main.throwing
        let text: String = try main.box.child().scaled(2, "x")
        #expect(text == "x6")
        let root: Double = try main.math.sqrt(4.0)
        #expect(root == 2)
    }

    @Test func missingAttributeThrowsAttributeError() {
        #expect(throws: PythonError.self) {
            try py.main.throwing.box.nope
        }
        do {
            _ = try py.main.throwing.box.nope
        } catch {
            #if cpython
            #expect(error.type == "AttributeError")
            #else
            #expect(error.type == .AttributeError)
            #endif
            #expect("\(error.value)".contains("nope"))
        }
    }

    @Test func noneIsAnObjectNotNil() throws {
        let none = try py.main.throwing.box.none
        #expect(none.object.reference.isNone)
        #expect(throws: PythonError.self) {
            let _: Int = try py.main.throwing.box.none
        }
    }

    @Test func raisedCallErrorPropagates() {
        #expect(throws: PythonError.self) {
            try py.main.throwing.box.scaled("a")
        }
    }

    @Test func setWritesAttribute() throws {
        try py.main.throwing.box.set("value", to: 5)
        let value: Int = try py.main.throwing.box.value
        #expect(value == 5)
        try py.main.throwing.box.set("value", to: nil)
        let cleared = try py.main.throwing.box.value
        #expect(cleared.object.reference.isNone)
    }
}
