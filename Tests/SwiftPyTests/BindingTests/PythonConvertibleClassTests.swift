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
    var number: Int? = nil
    
    init() {}
    init(a: Int, b: Int) {}
    init(a: Int, b: Int, c: Int) {}
    
    init(number: Int) {
        self.number = number
    }
    
    func setNumber(value: Int) {
        number = value
    }
    
    func getNumber() -> Int {
        number ?? -1
    }
    
    var _pythonCache = PythonBindingCache()
}

extension TestClass: CustomStringConvertible {
    var description: String {
        "TestClass(number: \(String(describing: number)))"
    }
}

extension TestClass: PythonBindable {
    static let pyType: PyType = .make("TestClass") { type in
        type.magic("__new__") { __new__($1) }
        type.magic("__init__") { argc, argv in
            __init__(argc, argv, TestClass.init) ||
            __init__(argc, argv, TestClass.init(number:)) ||
            __init__(argc, argv, TestClass.init(a:b:)) ||
            __init__(argc, argv, TestClass.init(a:b:c:)) ||
            PyAPI.throw(.TypeError, "Invalid arguments")
        }
        type.magic("__repr__") { __repr__($1) }
        type.property("number") {
            _bind_getter(\.number, $1)
        } setter: {
            _bind_setter(\.number, $1)
        }
        type.function("set_number(self, value: int) -> None") {
            _bind_function(setNumber, $1)
        }
        type.function("get_number(self) -> int") {
            _bind_function(getNumber, $1)
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
        Interpreter.run("import gc")
        Interpreter.run("test5 = TestClass(12)")
        
        let obj = try #require(main["test5"])

        #expect(TestClass(obj)?.number == 12)
    }
    
    @Test func wrongInit() throws {
        let test = try #require(Interpreter.evaluate("TestClass('str')"))
        #expect(!test.isType(TestClass.self))
    }
    
    @Test func pythonMutation() {
        let obj = TestClass(number: 32)
        obj.toPython(main.emplace("test4"))

        withKnownIssue {
            Interpreter.run("test4.number = 'asd'")
            #expect(obj.number == 32)
        }
        
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
        #expect(Interpreter.evaluate("test7.__repr__()") == obj.description)
    }
}
