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
    
    func setNumber(value: Int) {
        number = value
    }
    
    func getNumber() -> Int {
        number
    }
    
    var _pythonCache = PythonBindingCache()
}

extension TestClass: CustomStringConvertible {
    var description: String {
        "TestClass(number: \(number))"
    }
}

extension TestClass {
    static var hasDictionary: Bool { true }
}

extension TestClass: PythonBindable {
    static let pyType: PyType = .make("TestClass") { userdata in
        deinitFromPython(userdata)
    } bind: { type in
        type.magic("__new__") { _, _ in
            newPythonObject(PyAPI.returnValue, hasDictionary: true)
            return true
        }
        type.magic("__init__") { _, argv in
            ensureArgument(argv?[1], Int.self) { number in
                TestClass(number: number).storeInPython(argv)
            }
        }
        type.magic("__repr__") { _, argv in
            reprDescription(argv)
        }
        type.property(
            "number",
            getter: { argc, argv in
                PyAPI.return(TestClass(argv)?.number)
            },
            setter: { argc, argv in
                ensureArguments(argv, Int.self) { base, value in
                    base.number = value
                }
            }
        )
        type.function("set_number(self, value: int) -> None") { _, argv in
            ensureArguments(argv, Int.self) { obj, value in
                obj.setNumber(value: value)
            }
        }
        type.function("get_number(self) -> int") { _, argv in
            let result = TestClass(argv)?.getNumber()
            return PyAPI.return(result)
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
        
        #expect(obj._pythonCache.reference == nil)
        
        obj.toPython(main.emplace("test3"))
        
        Interpreter.input("test3.number")
        #expect(obj._pythonCache.reference != nil)
        
        // Uses cache.
        obj.toPython(main.emplace("test4"))
                
        Interpreter.run("del test3")
        Interpreter.input("gc.collect()")
        #expect(obj._pythonCache.reference != nil)
        
        Interpreter.run("del test4")
        Interpreter.input("gc.collect()")
        #expect(obj._pythonCache.reference == nil)
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
        
        Interpreter.run("test5.set_number(10)")
        #expect(obj.number == 10)
    }
    
    @Test func getNumber() {
        let obj = TestClass(number: 32)
        obj.toPython(main.emplace("test6"))
        
        #expect(Interpreter.evaluate("test6.get_number()") == 32)
    }

    @Test func repr() {
        let obj = TestClass(number: 32)
        obj.toPython(main.emplace("test7"))
        
        #expect(Interpreter.evaluate("test7.__repr__()") == "TestClass(number: 32)")
    }
}
