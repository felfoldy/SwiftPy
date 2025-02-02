//
//  PythonConvertibleClassTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import SwiftPy
import Testing
import pocketpy

struct TestStruct: PythonConvertible {
    var number: Int
    
    init?(_ reference: PyAPI.Reference) {
        if let number = Int(reference["number"]) {
            self.number = number
        } else {
            return nil
        }
    }
    
    static let pyType: py_Type = {
        let type = py_newtype("TestStruct", py_Type(tp_object.rawValue), nil, nil)

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
    
    func toPython(_ reference: PyAPI.Reference) {
        py_newobject(reference, Self.pyType, -1, 0)
        let r0 = py_getreg(0)
        number.toPython(r0)
        py_setdict(reference, py_name("number"), r0)
    }
}

class TestClass: PythonConvertible {
    let number = 32
    
    init() {}
    
    required convenience init?(_ reference: PyAPI.Reference) {
        self.init()
    }
    
    static let pyType: py_Type = {
        let type = py_newtype("TestClass", py_Type(tp_object.rawValue), nil, nil)
        
        py_bindproperty(type, "number", { argc, argv in
            if let ref = Int(py_getslot(argv, 0)),
               let pointer = UnsafeMutableRawPointer(bitPattern: ref) {
                let value = Unmanaged<TestClass>.fromOpaque(pointer).takeRetainedValue()
                PyAPI.returnValue.set(value.number)
                return true
            }
            
            PyAPI.returnValue.setNone()
            return true
        }, nil)

        return type
    }()
    
    func toPython(_ reference: PyAPI.Reference) {
        py_newobject(reference, TestClass.pyType, 1, 0)
        let value = Unmanaged.passRetained(self).toOpaque()
        let r0 = py_getreg(0)
        Int(bitPattern: value).toPython(r0)
        py_setslot(reference, 0, r0)
    }
}

@MainActor
struct PythonConvertibleClassTests {
    @Test func structBinding() throws {
        let main = Interpreter.main
        
        let typeObj = py_tpobject(TestStruct.pyType)
        py_setdict(main, py_name("TestStruct"), typeObj)
        
        Interpreter.run("x = TestStruct(32)")
        #expect(Interpreter.evaluate("x.number") == 32)
        
        Interpreter.run("x.number = 42")
        var x = try #require(TestStruct(main["x"]))
        #expect(x.number == 42)
        x.number = 32
        x.toPython(main["x"])
    }
    
    @Test func testClassBinding() {
        Interpreter.run("x = None")
        let instance = TestClass()
        instance.toPython(Interpreter.main["x"])

        // Register?
        let classObj = py_tpobject(TestClass.pyType)
        py_setdict(Interpreter.main, py_name("TestClass"), classObj)
        
        #expect(TestClass.pyType != nil)
        #expect(Interpreter.evaluate("x.number") == 32)
    }
}
