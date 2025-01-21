//
//  RawFunctionRegistrationTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-21.
//

import PythonTools
import pocketpy
import Testing

@MainActor
struct RawFunctionRegistrationTests {
    let main = Interpreter.main
    
    @Test func rawVoidFunctionRegistration() throws {
        var executed = false

        let function = FunctionRegistration(
            id: "id",
            name: "custom"
        ) {
            executed = true
        }
        cFunction: { _, _ in
            FunctionStore.voidFunctions["id"]?()
            PyAPI.returnValue.setNone()
            return true
        }

        try #require(FunctionStore.voidFunctions["id"] != nil)

        main.bind(function)
        Interpreter.execute("custom()")

        #expect(executed)
    }
    
    @Test func rawIntFunctionRegistration() throws {
        let function = FunctionRegistration(
            id: "id",
            signature: "custom() -> int"
        ) {
            42
        } cFunction: { _, _ in
            let result = FunctionStore.intFunctions["id"]?()
            PyAPI.returnValue.set(result)
            return true
        }

        try #require(FunctionStore.intFunctions["id"] != nil)

        main.bind(function)
        Interpreter.execute("x = custom()")

        #expect(main["x"]?.asInt() == 42)
    }

    @Test func rawStringFunctionRegistration() throws {
        let function = FunctionRegistration(
            id: "id",
            signature: "custom() -> str"
        ) {
            "Hello, World!"
        } cFunction: { _, _ in
            let result = FunctionStore.stringFunctions["id"]?()
            PyAPI.returnValue.set(result)
            return true
        }

        try #require(FunctionStore.stringFunctions["id"] != nil)
        
        main.bind(function)
        Interpreter.execute("x = custom()")

        #expect(main["x"]?.asStr() == "Hello, World!")
    }
    
    @Test func rawBoolFunctionRegistration() throws {
        let function = FunctionRegistration(
            id: "id",
            signature: "custom() -> bool"
        ) {
            true
        } cFunction: { _, _ in
            let result = FunctionStore.boolFunctions["id"]?()
            PyAPI.returnValue.set(result)
            return true
        }

        try #require(FunctionStore.boolFunctions["id"] != nil)

        main.bind(function)
        Interpreter.execute("x = custom()")

        #expect(main["x"]?.asBool() == true)
    }
}
