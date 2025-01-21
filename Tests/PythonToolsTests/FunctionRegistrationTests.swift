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
    @Test func voidFunctionRegistrationByName() {
        var executed = false

        let function = #def("custom") {
            executed = true
        }

        #expect(FunctionStore.voidFunctions[function.id] != nil)

        Interpreter.main.set(function)
        Interpreter.execute("custom()")

        #expect(executed)
    }
    
    @Test func voidFunctionRegistrationBySignature() {
        var executed = false

        let function = #def("custom() -> None") {
            executed = true
        }

        #expect(FunctionStore.voidFunctions[function.id] != nil)

        Interpreter.main.set(function)
        Interpreter.execute("custom()")

        #expect(executed)
    }

    @Test func intFunctionRegistration() throws {
        let function = #def("value() -> int") {
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

