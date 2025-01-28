//
//  OutputStreamTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-28.
//

import Testing
import SwiftPy

@MainActor
struct OutputStreamTests {
    @Test func outputEvaluation() {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream

        Interpreter.input("3 + 4")

        #expect(outputStream.lastStdOut == "7")
    }
    
    @Test func outputPrint() {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream

        Interpreter.input("print('str')")

        #expect(outputStream.lastStdOut == "str")
    }
    
    @Test func compilationError() throws {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream
        
        Interpreter.execute("some invalid code")

        let err = try #require(outputStream.lastStdErr)
        #expect(err.contains("SyntaxError"))
    }
    
    @Test func runtimeError() throws {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream
        
        Interpreter.execute("undefined_func()")
        
        let err = try #require(outputStream.lastStdErr)
        #expect(err.contains("NameError"))
    }
}

class TestOutputStream: OutputStream {
    var lastStdOut: String?
    var lastStdErr: String?
    
    func stdout(_ str: String) {
        lastStdOut = str
    }

    func stderr(_ str: String) {
        lastStdErr = str
    }
}
