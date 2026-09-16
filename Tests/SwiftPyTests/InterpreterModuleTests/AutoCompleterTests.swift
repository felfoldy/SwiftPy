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

    // CPython's rlcompleter offers the call form for every callable match;
    // the pocketpy one keeps a partial prefix plain, so it can still become
    // `print.` or `print(`.
    #if cpython
    private static let partial = "("
    #else
    private static let partial = ""
    #endif

    @Test()
    func globalMatches() {
        Interpreter.run("x = completer.complete('pri', 0)")
        #expect(py.main.x == "print" + Self.partial)

        // The whole name offers the call form (paren left open for the console).
        Interpreter.run("x = completer.complete('str', 0)")
        #expect(py.main.x == "str(")
    }

    @Test func attributeMatches() {
        Interpreter.run("x = completer.complete('completer.comp', 0)")
        #expect(py.main.x == "completer.complete" + Self.partial)

        // Full attribute name offers the call form.
        Interpreter.run("x = completer.complete('completer.complete', 0)")
        #expect(py.main.x == "completer.complete(")
    }

    @Test func complete() {
        let completions = Interpreter.complete("s")

        #expect(completions.contains("str" + Self.partial))
        #expect(completions.contains("setattr" + Self.partial))
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
