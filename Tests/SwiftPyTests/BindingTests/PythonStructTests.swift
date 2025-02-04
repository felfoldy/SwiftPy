//
//  PythonStructTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import Testing
import SwiftPy
import pocketpy

struct TestStruct: PythonConvertible {
    var number: Int
    
    init(number: Int) {
        self.number = number
    }
    
    init?(_ reference: PyAPI.Reference) {
        if let number = Int(reference["number"]) {
            self.number = number
        } else {
            return nil
        }
    }
    
    static let pyType: PyType = {
        let type = py_newtype("TestStruct", .object, Interpreter.main, nil)

        // __new__
        py_newnativefunc(py_tpgetmagic(type, py_name("__new__"))) { argc, argv in
            py_newobject(PyAPI.returnValue, py_totype(argv), -1, 0)
            return true
        }
        
        // __init__
        py_newnativefunc(py_tpgetmagic(type, py_name("__init__"))) { argc, argv in
            py_setdict(argv, py_name("number"), argv?[1])
            PyAPI.returnValue.setNone()
            return true
        }
        
        return type
    }()
    
    mutating func toPython(_ reference: PyAPI.Reference) {
        py_newobject(reference, Self.pyType, -1, 0)
        let r0 = py_getreg(0)
        number.toPython(r0)
        py_setdict(reference, py_name("number"), r0)
    }
}

@MainActor
struct PythonStructTests {
    @Test func structBinding() throws {
        let main = Interpreter.main
        TestStruct.pyType
        
        // Create from python.
        Interpreter.run("x = TestStruct(32)")
        #expect(Interpreter.evaluate("x.number") == 32)
        
        // Update from python.
        Interpreter.run("x.number = 42")
        var x = try #require(TestStruct(main["x"]))
        #expect(x.number == 42)

        // Change it back in swift
        x.number = 32
        x.toPython(main["x"])
        #expect(Interpreter.evaluate("x.number") == 32)
    }
}
