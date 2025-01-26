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
        #expect(buffer == "for i in range(3, 10):")

        // Evaluate each i
        Interpreter.input("    i")
        // Exit multiline.
        #expect(Interpreter.input("").isEmpty)
    }
    
    @Test func justEvaluate() {
        #expect(Interpreter.input("3 + 4").isEmpty)
    }
    
    @Test func importModule() {
        // TODO: Expect errors to output.
        Interpreter.execute("import justx")
        
        var moduleName: String?
        Interpreter.onImport = { module in
            moduleName = module
            return "x = 10"
        }

        Interpreter.execute("import justx")
        #expect(moduleName == "justx.py")
        
        #expect(Interpreter.shared.module("justx")?["x"] == 10)
    }
    
    @Test func loadBundleModule() {
        Interpreter.execute("from rlcompleter import Completer")
        // TODO: expect no errors.
    }
}
