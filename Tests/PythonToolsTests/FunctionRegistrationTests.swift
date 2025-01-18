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
}

