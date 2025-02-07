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
}

extension TestClass: PythonConvertible {
    static let pyType: PyType = {
        py_newtype("TestClass", .object, Interpreter.main) { userdata in
            TestClass.load(from: userdata)?.release()
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

            PyAPI.return(.none)
            return true
        }
        .bindProperty("number") { argc, argv in
            PyAPI.return(TestClass(argv)?.number)
            return true
        }
    }()
    
    func toPython(_ reference: PyAPI.Reference) {
        let userdata = py_newobject(reference, TestClass.pyType, 0, PyAPI.pointerSize)
        retainedReference().store(in: userdata)
    }

    static func fromPython(_ reference: PyAPI.Reference) -> TestClass {
        load(from: py_touserdata(reference))!.takeUnretainedValue()
    }
}

@MainActor
struct PythonConvertibleClassTests {    
    @Test func testClassReferenceCounting() async throws {
        let main = Interpreter.main
        
        var instance: TestClass? = TestClass(number: 32)
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
    
    @Test func initFromPython() async throws {
        Interpreter.run("test = TestClass(32)")
        #expect(Interpreter.evaluate("test.number") == 32)
    }
}
