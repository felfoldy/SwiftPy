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
    var number: Int
    
    init(number: Int) {
        self.number = number
    }
    
    func setNumber() {
        number = 10
    }
    
    var _cachedPythonReference: PyAPI.Reference?
}

extension TestClass: PythonBindable {
    static let pyType: PyType = .make("TestClass") { userdata in
        deinitFromPython(userdata)
    } bind: { type in
        type.magic("__new__") { _, _ in
            newPythonObject(PyAPI.returnValue)
            return true
        }
        type.magic("__init__") { argc, argv in
            guard let number = Int(argv?[1]) else {
                return PyAPI.throw(.TypeError, "missing 1 required positional argument: 'number'")
            }
            
            TestClass(
                number: number
            )
            .storeInPython(argv, userdata: py_touserdata(argv))
            
            return PyAPI.return(.none)
        }
        type.property(
            "number",
            getter: { argc, argv in
                return PyAPI.return(TestClass(argv)?.number)
            },
            setter: { argc, argv in
                guard let value = Int(argv?[1]) else {
                    return PyAPI.throw(.TypeError, "Expected Int at position 1")
                }

                TestClass(argv)?.number = value
                
                return PyAPI.return(.none)
            }
        )
        py_bind(py_tpobject(type), "set_number(self) -> None") { _, argv in
            TestClass(argv)?.setNumber()
            return PyAPI.return(.none)
        }
    }
}

@MainActor
struct PythonConvertibleClassTests {
    let main = Interpreter.main
    let type = TestClass.pyType
    
    @Test func returnCachedFromToPython() throws {
        Interpreter.run("import gc")

        let obj = TestClass(number: 12)
        
        #expect(obj._cachedPythonReference == nil)
        
        obj.toPython(main.emplace("test3"))
        
        Interpreter.input("test3.number")
        #expect(obj._cachedPythonReference != nil)
        
        // Uses cache.
        obj.toPython(main.emplace("test4"))
                
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
    
    @Test func wrongInit() throws {
        let test = try #require(Interpreter.evaluate("TestClass('str')"))
        #expect(!test.isType(TestClass.self))
    }
    
    @Test func pythonMutation() {
        let obj = TestClass(number: 32)
        obj.toPython(main.emplace("test4"))

        Interpreter.run("test4.number = 'asd'")
        #expect(obj.number == 32)
        
        Interpreter.run("test4.number = 42")
        #expect(obj.number == 42)
    }
    
    @Test func functionBinding() {
        let obj = TestClass(number: 32)
        obj.toPython(main.emplace("test5"))
        
        Interpreter.run("test5.set_number()")
        #expect(obj.number == 10)
    }
}
