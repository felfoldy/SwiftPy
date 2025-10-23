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

        Interpreter.run("3 + 4", mode: .single)

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
    
    @Test func outputPrint() {
        let outputStream = TestOutputStream()
        Interpreter.output = outputStream

        Interpreter.run("print('str')")

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
        print(str)
    }

    func stderr(_ str: String) {
        lastStdErr = str
        print(str)
    }
}
