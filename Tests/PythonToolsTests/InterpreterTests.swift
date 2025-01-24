//
//  InterpreterTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import Testing
@testable import SwiftPy
import pocketpy

@MainActor
struct InterpreterTests {
    @Test func buffer() {
        let buffer = Interpreter.input("""
        for i in range(3, 10):
        """)

        // Store in buffer instead of executing it.
        #expect(buffer == "for i in range(3, 10):\n")

        // Evaluate each i
        Interpreter.input("    i")
        // Exit multiline.
        #expect(Interpreter.input("").isEmpty)
    }
    
    @Test func justEvaluate() {
        #expect(Interpreter.input("3 + 4").isEmpty)
    }
}
