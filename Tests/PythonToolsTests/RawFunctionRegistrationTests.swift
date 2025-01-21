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
            PK.returnNone()
            return true
        }

        try #require(FunctionStore.voidFunctions["id"] != nil)

        Interpreter.main.set(function)
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
            PK.returnInt(result)
            return true
        }

        try #require(FunctionStore.intFunctions["id"] != nil)

        Interpreter.main.set(function)
        Interpreter.execute("x = custom()")

        let item = py_getglobal(py_name("x"))
        try #require(py_istype(item, py_Type(tp_int.rawValue)))

        let result = py_toint(item)
        #expect(result == 42)
    }

    @Test func rawStringFunctionRegistration() throws {
        let function = FunctionRegistration(
            id: "id",
            signature: "custom() -> str"
        ) {
            "Hello, World!"
        } cFunction: { _, _ in
            let result = FunctionStore.stringFunctions["id"]?()
            PK.returnStr(result)
            return true
        }

        try #require(FunctionStore.stringFunctions["id"] != nil)
        
        Interpreter.main.set(function)
        Interpreter.execute("x = custom()")
        
        let item = py_getglobal(py_name("x"))
        try #require(py_istype(item, py_Type(tp_str.rawValue)))
        
        let result = String(cString: py_tostr(item)!)
        #expect(result == "Hello, World!")
    }
    
    @Test func rawBoolFunctionRegistration() throws {
        let function = FunctionRegistration(
            id: "id",
            signature: "custom() -> bool"
        ) {
            true
        } cFunction: { _, _ in
            let result = FunctionStore.boolFunctions["id"]?()
            PK.returnBool(result)
            return true
        }

        try #require(FunctionStore.boolFunctions["id"] != nil)

        Interpreter.main.set(function)
        Interpreter.execute("x = custom()")

        let item = py_getglobal(py_name("x"))
        try #require(py_istype(item, py_Type(tp_bool.rawValue)))

        let result = py_tobool(item)
        #expect(result)
    }
}
