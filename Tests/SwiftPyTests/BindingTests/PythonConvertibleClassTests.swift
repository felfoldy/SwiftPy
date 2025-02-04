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
    var number = 32
    
    init() {}
    
    required convenience init?(_ reference: PyAPI.Reference) {
        self.init()
    }
    
    static let pyType: PyType = {
        let type = py_newtype("TestClass", .object, nil) { userdata in
            if let pointer = userdata?.load(as: UnsafeRawPointer.self) {
                Unmanaged<TestClass>.fromOpaque(pointer).release()
            }
        }

        py_bindproperty(type, "number", { argc, argv in
            let pointer = py_touserdata(argv)
                .load(as: UnsafeRawPointer.self)
            let obj = Unmanaged<TestClass>.fromOpaque(pointer)
                .takeUnretainedValue()
            PyAPI.returnValue.set(obj.number)
            return true
        }, nil)

        return type
    }()
    
    func toPython(_ reference: PyAPI.Reference) {
        let pointer = Unmanaged.passRetained(self).toOpaque()
        let userdata = py_newobject(reference, TestClass.pyType, 0, Int32(MemoryLayout<UnsafeRawPointer>.size))
        userdata?.storeBytes(of: pointer, as: UnsafeRawPointer.self)
    }
}

@MainActor
struct PythonConvertibleClassTests {    
    @Test func testClassBinding() async throws {
        let main = Interpreter.main
        
        let instance = TestClass()
        print("Retain count: \(CFGetRetainCount(instance))") // 2

        let r0 = py_getreg(0)
        instance.toPython(r0)
        main.setAttribute("test", r0)
        print("Retain count: \(CFGetRetainCount(instance))") // 3

        #expect(Interpreter.evaluate("test.number") == 32)
        
        print("Retain count: \(CFGetRetainCount(instance))") // Still 3?
    }
}

//@MainActor var isDtorCalled = false
//
//@MainActor
//@Test func testDtor() {
//    py_initialize()
//
//    py_import("gc")
//    
//    let main = py_getmodule("__main__")
//    let tp_MyClass = py_newtype("MyClass", py_Type(tp_object.rawValue), main) { _ in
//        isDtorCalled = true
//    }
//    
//    // Create test object.
//    py_newobject(py_emplacedict(main, py_name("test")), tp_MyClass, 0, 0)
//    
//    // del test
//    py_deldict(main, py_name("test"))
//    py_exec("gc.collect()", "<string>", EXEC_MODE, main)
//
//    #expect(isDtorCalled)
//}
