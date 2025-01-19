//
//  FunctionRegistrationTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import PythonTools
import Testing
import pocketpy

@MainActor
struct FunctionRegistrationTests {
    @Test func voidFunctionRegistration() {
        var executed = false

        let function = #pythonFunction("custom") {
            executed = true
        }

        #expect(!FunctionStore.voidFunctions.isEmpty)

        Interpreter.main.set(function)
        Interpreter.execute("custom()")

        #expect(executed)
    }
    
    @Test func intFunctionRegistration() throws {
        let function = #pythonFunction("value", signature: .int) {
            42
        }
        
        Interpreter.main.set(function)
        Interpreter.execute("x = value()")
        
        let item = py_getglobal(py_name("x"))
        try #require(py_istype(item, py_Type(tp_int.rawValue)))

        let result = py_toint(item)
        #expect(result == 42)
    }
}

