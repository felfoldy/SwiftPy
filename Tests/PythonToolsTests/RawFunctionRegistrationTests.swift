//
//  RawFunctionRegistrationTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-21.
//

@testable import PythonTools
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
        ) { _ in
            executed = true
        }
        cFunction: { _, _ in
            FunctionStore.voidFunctions["id"]?(.none)
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
            let result = FunctionStore.intFunctions["id"]?(.none)
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
            let result = FunctionStore.stringFunctions["id"]?(.none)
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
            let result = FunctionStore.boolFunctions["id"]?(.none)
            PyAPI.returnValue.set(result)
            return true
        }

        try #require(FunctionStore.boolFunctions["id"] != nil)

        main.bind(function)
        Interpreter.execute("x = custom()")

        #expect(main["x"]?.asBool() == true)
    }
    
    @Test func argumentedVoidFunctionRegistration() throws {
        var secretValue: Int?
        
        let function = FunctionRegistration(
            id: "id",
            signature: "custom(value: int)"
        ) { args in
            secretValue = args[0]?.asInt()
        } cFunction: { argc, argv in
            let arguments = FunctionArguments(argc: argc, argv: argv)
            FunctionStore.voidFunctions["id"]?(arguments)
            PyAPI.returnValue.setNone()
            return true
        }
        
        main.bind(function)
        Interpreter.execute("custom(42)")
        
        #expect(secretValue == 42)
    }
}
