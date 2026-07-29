//
//  AutoCompleterTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-24.
//

import Testing
import SwiftPy

@MainActor
struct AutoCompleterTests {
    init() {
        Interpreter.run("from rlcompleter import Completer")
        Interpreter.run("completer = Completer()")
    }

    @Test func returnTabOnEmptyString() {
        Interpreter.run("x = completer.complete('', 0)")

        #expect(py.main.x == "\t")
    }

    @Test()
    func globalMatches() {
        // A partial prefix stays plain so it can still become `print.`/`print(`.
        Interpreter.run("x = completer.complete('pri', 0)")
        #expect(py.main.x == "print")

        // The whole name offers the call form (paren left open for the console).
        Interpreter.run("x = completer.complete('str', 0)")
        #expect(py.main.x == "str(")
    }

    @Test func attributeMatches() {
        // Partial attribute stays plain.
        Interpreter.run("x = completer.complete('completer.comp', 0)")
        #expect(py.main.x == "completer.complete")

        // Full attribute name offers the call form.
        Interpreter.run("x = completer.complete('completer.complete', 0)")
        #expect(py.main.x == "completer.complete(")
    }

    @Test func complete() {
        // Prefix matches are partial, so they stay plain.
        let completions = Interpreter.complete("s")

        #expect(completions.contains("str"))
        #expect(completions.contains("setattr"))
    }
    
    @Test func completeKeywords_addsColon() {
        let completions = Interpreter.complete("try")
        #expect(completions.contains("try:"))
        
        let completions2 = Interpreter.complete("finally")
        #expect(completions2.contains("finally:"))
    }
    
    @Test func completerKeywords_addsSpace() {
        let completions = Interpreter.complete("if")
        #expect(completions.contains("if "))
        
        let completions2 = Interpreter.complete("None")
        #expect(completions2.contains("None"))
    }
}
