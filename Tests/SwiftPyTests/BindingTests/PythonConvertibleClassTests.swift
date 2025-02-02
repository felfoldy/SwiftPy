//
//  PythonConvertibleClassTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import SwiftPy
import Testing
import pocketpy
import CoreFoundation

class TestClass: PythonConvertible {
    let number = 32
    
    init() {}
    
    required convenience init?(_ reference: PyAPI.Reference) {
        self.init()
    }
    
    static let pyType: py_Type = {
        let type = py_newtype("TestClass",
                              py_Type(tp_object.rawValue),
                              nil) { userdata in
            // There is only 1 slot. Slot 0 should be 16 bytes before the userdata.
            // TODO: `del obj` does not trigger dtor call. why?
            let slot0 = Int(bitPattern: userdata) - 16
            if let pointer = UnsafeRawPointer(bitPattern: slot0) {
                Unmanaged<TestClass>.fromOpaque(pointer).release()
            }
        }

        py_bindproperty(type, "number", { argc, argv in
            if let ref = Int(py_getslot(argv, 0)),
               let pointer = UnsafeMutableRawPointer(bitPattern: ref) {
                let value = Unmanaged<TestClass>.fromOpaque(pointer).takeUnretainedValue()
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
    @Test func testClassBinding() async throws {
        Interpreter.run("x = None")

        let instance = TestClass()
        print("Retain count: \(CFGetRetainCount(instance))")

        instance.toPython(Interpreter.main["x"])
        print("Retain count: \(CFGetRetainCount(instance))")
        
        Interpreter.input("x.number")
        
        #expect(Interpreter.evaluate("x.number") == 32)
        
        Interpreter.run("del x")
        Interpreter.run("import gc; gc.collect()")
        
        try await Task.sleep(for: .seconds(1))
        
        print("Retain count: \(CFGetRetainCount(instance))")
    }
}
