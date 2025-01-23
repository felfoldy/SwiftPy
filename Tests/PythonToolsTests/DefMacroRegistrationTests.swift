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
struct DefMacroRegistrationTests {
    let main = Interpreter.main
    
    @Test func voidFunctionRegistrationByName() {
        var executed = false

        let function = #def("custom") {
            executed = true
        }

        #expect(FunctionStore.voidFunctions[function.id] != nil)

        main.bind(function)
        Interpreter.execute("custom()")

        #expect(executed)
    }
    
    @Test func voidFunctionRegistrationBySignature() {
        var executed = false

        let function = #def("custom() -> None") {
            executed = true
        }

        #expect(FunctionStore.voidFunctions[function.id] != nil)

        main.bind(function)
        Interpreter.execute("custom()")

        #expect(executed)
    }

    @Test func intFunctionRegistration() throws {
        let function = #def("value() -> int") {
            42
        }
        
        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(Int(main["x"]) == 42)
    }
    
    @Test func stringFunctionRegistration() throws {
        let function = #def("value() -> str") {
            "Hello, World!"
        }
        
        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(String(main["x"]) == "Hello, World!")
    }
    
    @Test func boolFunctionRegistration() throws {
        let function = #def("value() -> bool") {
            true
        }

        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(Bool(main["x"]) == true)
    }
    
    @Test func floatFunctionRegistration() throws {
        let function = #def("value() -> float") {
            3.14
        }

        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(Double(main["x"]) == 3.14)
    }
}
