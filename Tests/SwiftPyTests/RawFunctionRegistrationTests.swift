//
//  RawFunctionRegistrationTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-21.
//

@testable import SwiftPy
import pocketpy
import Testing

@MainActor
struct RawFunctionRegistrationTests {
    let main = Interpreter.main

    init() {
        FunctionStore.voidFunctions.removeAll()
        FunctionStore.returningFunctions.removeAll()
    }

    @Test func rawVoidFunctionRegistration() throws {
        var executed = false

        let function = FunctionRegistration.void(
            id: "id",
            signature: "custom() -> None",
            block: { _ in
                executed = true
            },
            cFunction: { _, _ in
                FunctionStore.voidFunctions["id"]?(.none)
                PyAPI.returnValue.setNone()
                return true
            }
        )

        try #require(FunctionStore.voidFunctions["id"] != nil)

        main.bind(function)
        Interpreter.execute("custom()")

        #expect(executed)
    }
    
    @Test func rawIntFunctionRegistration() throws {
        let function = FunctionRegistration.returning(
            id: "id",
            signature: "custom() -> int",
            block: { _ in
                42
            },
            cFunction: { _, _ in
                let result = FunctionStore.returningFunctions["id"]?(.none)
                PyAPI.returnValue.set(result)
                return true
            }
        )

        try #require(FunctionStore.returningFunctions["id"] != nil)

        main.bind(function)
        Interpreter.execute("x = custom()")

        #expect(main["x"] == 42)
    }

    @Test func rawStringFunctionRegistration() throws {
        let function = FunctionRegistration.returning(
            id: "id",
            signature: "custom() -> str",
            block: { _ in
                "Hello, World!"
            },
            cFunction: { _, _ in
                let result = FunctionStore.returningFunctions["id"]?(.none)
                PyAPI.returnValue.set(result)
                return true
            }
        )

        try #require(FunctionStore.returningFunctions["id"] != nil)
        
        main.bind(function)
        Interpreter.execute("x = custom()")

        #expect(main["x"] == "Hello, World!")
    }

    @Test func rawBoolFunctionRegistration() throws {
        let function = FunctionRegistration.returning(
            id: "id",
            signature: "custom() -> bool",
            block: { _ in
                true
            },
            cFunction: { _, _ in
                let result = FunctionStore.returningFunctions["id"]?(.none)
                PyAPI.returnValue.set(result)
                return true
            }
        )

        try #require(FunctionStore.returningFunctions["id"] != nil)

        main.bind(function)
        Interpreter.execute("x = custom()")

        #expect(main["x"] == true)
    }

    @Test func argumentedVoidFunctionRegistration() throws {
        var secretValue: Int?
        
        let function = FunctionRegistration.void(
            id: "id",
            signature: "custom(value: int)",
            block: { args in
                secretValue = args[0]
            },
            cFunction: { argc, argv in
                let arguments = FunctionArguments(argc: argc, argv: argv)
                FunctionStore.voidFunctions["id"]?(arguments)
                PyAPI.returnValue.setNone()
                return true
            }
        )
        
        main.bind(function)
        Interpreter.execute("custom(42)")
        
        #expect(secretValue == 42)
    }
}
