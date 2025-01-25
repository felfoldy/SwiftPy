//
//  AutoCompleterTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-24.
//

import Testing
import SwiftPy
import pocketpy

@MainActor
struct AutoCompleterTests {
    init() {
        Interpreter.input("from rlcompleter import Completer")
        Interpreter.input("completer = Completer()")
    }
    
    @Test func returnTabOnEmptyString() {
        Interpreter.input("x = completer.complete('', 0)")

        #expect(Interpreter.main["x"] == "\t")
    }
    
    @Test func globalMatches() {
        Interpreter.input("x = completer.complete('s', 0)")
        #expect(Interpreter.main["x"] == "str(")
        
        Interpreter.input("x = completer.complete('str', 0)")
        #expect(Interpreter.main["x"] == "str(")
    }
    
    @Test func attributeMatches() {
        Interpreter.input("x = completer.complete('completer.c', 0)")
        #expect(Interpreter.main["x"] == "completer.complete(")
    }
    
    @Test func complete() {
        let completions = Interpreter.complete("s")
        
        #expect(completions.contains("str("))
        #expect(completions.contains("setattr("))
    }
}
