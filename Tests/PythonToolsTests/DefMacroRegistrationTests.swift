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

    @Test func intFunctionRegistration() {
        let function = #def("value() -> int") {
            42
        }
        
        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(main["x"] == 42)
    }
    
    @Test func stringFunctionRegistration() {
        let function = #def("value() -> str") {
            "Hello, World!"
        }
        
        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(main["x"] == "Hello, World!")
    }
    
    @Test func boolFunctionRegistration() {
        let function = #def("value() -> bool") {
            true
        }

        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(main["x"] == true)
    }
    
    @Test func floatFunctionRegistration() {
        let function = #def("value() -> float") {
            3.14
        }

        main.bind(function)
        Interpreter.execute("x = value()")

        #expect(main["x"] == 3.14)
    }
    
    @Test func argumentedFuntionRegistration() {
        let function = #def("add(a: int, b: int) -> int") { args in
            let a: Int = args[0]!
            let b: Int = args[1]!
            return a + b
        }

        main.bind(function)
        Interpreter.execute("x = add(10, 3)")

        #expect(main["x"] == 13)
    }}
