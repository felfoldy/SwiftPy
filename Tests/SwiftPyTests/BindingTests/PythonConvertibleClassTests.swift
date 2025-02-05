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
    @Test func testClassReferenceCounting() async throws {
        let main = Interpreter.main
        
        var instance: TestClass? = TestClass()
        func retainCount() -> Int {
            if let instance {
                Int(CFGetRetainCount(instance))
            } else { 0 }
        }
        
        var lastRetainCount = retainCount()
        
        instance!.toPython(py_emplacedict(main, py_name("test")))
        #expect(lastRetainCount < retainCount())
        lastRetainCount = retainCount()

        #expect(Interpreter.evaluate("test.number") == 32)
        
        Interpreter.run("del test")
        Interpreter.run("import gc; gc.collect()")
        instance = nil
        #expect(retainCount() == 0)
    }
}
