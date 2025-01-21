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

        #expect(main["x"]?.asInt() == 42)
    }
    
    @Test func stringFunctionRegistration() throws {
        let function = #def("value() -> str") {
            "Hello, World!"
        }
        
        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(main["x"]?.asStr() == "Hello, World!")
    }
    
    @Test func boolFunctionRegistration() throws {
        let function = #def("value() -> bool") {
            true
        }

        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(main["x"]?.asBool() == true)
    }
    
    @Test func floatFunctionRegistration() throws {
        let function = #def("value() -> float") {
            3.14
        }

        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(main["x"]?.asFloat() == 3.14)
    }
}
