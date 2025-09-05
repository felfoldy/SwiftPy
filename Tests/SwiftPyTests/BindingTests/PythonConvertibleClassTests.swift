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

final class TestClass: HasSubscript {
    /// Just a number.
    var number: Int? = nil
    
    init() {}
    
    init(number: Int) {
        self.number = number
    }

    /// Init with multiple parameters.
    init(a: Int, b: Int) {
        self.number = b
    }
    init(a: Int, b: Int, c: Int) {}

    func setNumber(value: Int? = nil) {
        number = value
    }
    
    func getNumber() -> Int {
        number ?? -1
    }
    
    subscript(key: String) -> String {
        key
    }

    static func staticFunc(value: Int) -> TestClass {
        TestClass(number: 10)
    }

    static func asyncCreate() async -> TestClass {
        TestClass(number: 10)
    }

    var _pythonCache = PythonBindingCache()
}

extension TestClass: @preconcurrency CustomStringConvertible {
    var description: String {
        "TestClass(number: \(String(describing: number)))"
    }
}

extension TestClass: PythonBindable {
    static let pyType: PyType = .make("TestClass", module: .main) { type in
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
        type.function("set_number(self, value: int | None) -> None") {
            _bind_function($1, setNumber)
        }
        type.function("get_number(self) -> int") {
            _bind_function($1, getNumber)
        }
        type.staticFunction("static_func") { argc, argv in
            PyBind.function(argc, argv, staticFunc)
        }
        type.staticFunction("async_create") { argc, argv in
            PyBind.function(argc, argv, asyncCreate)
        }
        type.magic("__getitem__") { argc, argv in
            __getitem__(argc, argv, __getitem__)
        }
        type.object?.setAttribute("_interface",
            #"""
            class TestClass(builtins.object):
                number: int
                """Just a number."""
            
                @overload
                def __init__(self): ...
                @overload
                def __init__(self, number: int): ...
                @overload
                def __init__(self, a: int, b: int):
                    """Init with multiple parameters."""
                @overload
                def __init__(self, a: int, b: int, c: int): ...
            
                def set_number(self, value: int) -> None: ...
                def get_number(self) -> int: ...
                @staticmethod
                def static_func(value: int) -> TestClass: ...
            """#
            .toRegister(0)
        )
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
        
        Interpreter.run("test3.number")
        #expect(obj._pythonCache.reference != nil)
        
        // Uses cache.
        obj.toPython(main.emplace("test4"))
                
        Interpreter.run("del test3")
        Interpreter.run("gc.collect()")
        #expect(obj._pythonCache.reference != nil)
        
        Interpreter.run("del test4")
        Interpreter.run("gc.collect()")
        #expect(obj._pythonCache.reference == nil)
    }
    
    @Test func createFromPython() throws {
        Interpreter.run("import gc")
        Interpreter.run("test5 = TestClass(12)")
        
        let obj = try #require(main["test5"])

        #expect(TestClass(obj)?.number == 12)
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
        
        Interpreter.run("test5.set_number(None)")
        #expect(obj.number == nil)
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
    
    @Test func staticFunc() throws {
        let obj: TestClass = try #require(Interpreter.evaluate("TestClass.static_func(10)"))
        #expect(obj.number == 10)
    }
    
    @Test func bindSubscript() throws {
        TestClass(number: 2)
            .toPython(main.emplace("test8"))
        #expect(Interpreter.evaluate("test8['str']") == "str")
    }
    
    @Test func asyncStaticFunc() async throws {
        await Interpreter.asyncRun("""
        test9 = await TestClass.async_create()
        """)

        let result = try #require(TestClass(.main["test9"]))
        #expect(result.number == 10)
    }
}
