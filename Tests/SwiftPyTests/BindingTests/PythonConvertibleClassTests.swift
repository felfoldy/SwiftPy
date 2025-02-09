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

final class TestClass {
    let number: Int
    
    init(number: Int) {
        self.number = number
    }
    
    private(set) var _cachedPythonReference: PyAPI.Reference?
}

extension TestClass: PythonConvertible {
    static let pyType: PyType = PyType
        .make("TestClass") { userdata in
            guard let userdata,
                  let unmanaged = TestClass.load(from: userdata)
            else { return }
            
            let obj = unmanaged.takeRetainedValue()
            UnsafeRawPointer(obj._cachedPythonReference)?.deallocate()
            obj._cachedPythonReference = nil
        }
        .bindMagic("__new__") { _, _ in
            py_newobject(PyAPI.returnValue, pyType, 0, PyAPI.pointerSize)
            return true
        }
        .bindMagic("__init__") { argc, argv in
            let userdata = py_touserdata(argv?[0])
            let number = Int.fromPython(argv?[1])!
            TestClass(number: number)
                .retainedReference()
                .store(in: userdata)

            let obj = TestClass(number: number)
            obj.retainedReference().store(in: userdata)
            
            let pointer = UnsafeMutableRawPointer.allocate(byteCount: 16, alignment: 8)
            let opaquePointer = OpaquePointer(pointer)
            py_assign(opaquePointer, argv)
            obj._cachedPythonReference = opaquePointer

            PyAPI.return(.none)
            return true
        }
        .bindProperty("number") { argc, argv in
            PyAPI.return(TestClass(argv)?.number)
            return true
        }
    
    func toPython(_ reference: PyAPI.Reference) {
        if let _cachedPythonReference {
            py_assign(reference, _cachedPythonReference)
            return
        }
        
        let userdata = TestClass.newPythonObject(reference)
        retainedReference().store(in: userdata)

        // sizeof(py_TValue) == 16
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: 16, alignment: 8)
        let opaquePointer = OpaquePointer(pointer)
        py_assign(opaquePointer, reference)
        _cachedPythonReference = opaquePointer
    }

    static func fromPython(_ reference: PyAPI.Reference) -> TestClass {
        load(from: py_touserdata(reference))!.takeUnretainedValue()
    }
}

@MainActor
struct PythonConvertibleClassTests {
    let type = TestClass.pyType
    
    @Test func returnCachedFromToPython() throws {
        let main = Interpreter.main
        Interpreter.run("import gc")

        let obj = TestClass(number: 12)
        
        #expect(obj._cachedPythonReference == nil)
        
        obj.toPython(main.emplace("test3"))
        
        Interpreter.input("test3.number")
        #expect(obj._cachedPythonReference != nil)
        
        // Uses cache.
        obj.toPython(main.emplace("test4"))
        
        // TODO: Needed to remove reference. How to workaround?
        py_newnone(obj._cachedPythonReference)
        
        Interpreter.run("del test3")
        Interpreter.input("gc.collect()")
        #expect(obj._cachedPythonReference != nil)
        
        Interpreter.run("del test4")
        Interpreter.input("gc.collect()")
        #expect(obj._cachedPythonReference == nil)
    }
    
    @Test func createFromPython() throws {
        let obj = try #require(Interpreter.evaluate("TestClass(12)"))
        #expect(TestClass(obj)?.number == 12)
    }
}
