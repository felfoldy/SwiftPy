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
    @Test func importModule() {
        Interpreter.execute("import justx")
        
        #expect(Interpreter.main["justx"] == nil)
        
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
        #expect(Interpreter.main["Completer"] != nil)
    }
    
    @Test func evaluate() {
        #expect(Interpreter.evaluate("3 + 4") == 7)
    }
}
