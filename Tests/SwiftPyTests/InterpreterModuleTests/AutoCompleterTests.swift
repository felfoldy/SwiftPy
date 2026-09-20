//
//  AutoCompleterTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-24.
//

import Testing
import SwiftPy

@MainActor
@Suite(.serialized)
struct AutoCompleterTests {
    init() async {
        await Interpreter.run("from rlcompleter import Completer")
        await Interpreter.run("completer = Completer()")
    }

    @Test func returnTabOnEmptyString() async {
        await Interpreter.run("completion = completer.complete('', 0)")

        #expect(py.main.completion == "\t")
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
    func globalMatches() async {
        await Interpreter.run("completion = completer.complete('pri', 0)")
        #expect(py.main.completion == "print" + Self.partial)

        // The whole name offers the call form (paren left open for the console).
        await Interpreter.run("completion = completer.complete('str', 0)")
        #expect(py.main.completion == "str(")
    }

    @Test func attributeMatches() async {
        await Interpreter.run("completion = completer.complete('completer.comp', 0)")
        #expect(py.main.completion == "completer.complete" + Self.partial)

        // Full attribute name offers the call form.
        await Interpreter.run("completion = completer.complete('completer.complete', 0)")
        #expect(py.main.completion == "completer.complete(")
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
