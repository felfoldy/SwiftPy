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
    @Test func outputEvaluation() throws {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream

        Interpreter.input("3 + 4")

        #expect(outputStream.lastInput == "3 + 4")
        #expect(outputStream.lastStdOut == "7")
        
        let time = try #require(outputStream.lastExecutionTime)
        #expect(time > 0)
    }
    
    @Test func runOutput() throws {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream

        Interpreter.run("print('str')")

        #expect(outputStream.lastInput == "print('str')")
        #expect(outputStream.lastStdOut == "str")
        
        let time = try #require(outputStream.lastExecutionTime)
        #expect(time > 0)
    }
    
    @Test func multileREPLOutput() throws {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream
        
        Interpreter.input("for i in range(0, 3):")
        Interpreter.input("    i")
        Interpreter.input("")
        
        #expect(outputStream.lastInput == "")
        #expect(outputStream.lastStdOut == "2")
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

class TestOutputStream: IOStream {
    var lastInput: String?
    var lastStdOut: String?
    var lastStdErr: String?
    var lastExecutionTime: UInt64?
    
    func input(_ str: String) {
        lastInput = str
    }
    
    func executionTime(_ time: UInt64) {
        lastExecutionTime = time
    }
    
    func stdout(_ str: String) {
        lastStdOut = str
    }

    func stderr(_ str: String) {
        lastStdErr = str
    }
}
