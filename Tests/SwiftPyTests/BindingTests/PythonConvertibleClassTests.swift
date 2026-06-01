//
//  PythonConvertibleClassTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import SwiftPy
import Testing
import CoreFoundation

@MainActor
final class TestClass {
    /// Just a number.
    var number: Int? = nil
    
    static let text = "Hello"
    
    init() {}
    
    init(number: Int) {
        self.number = number
    }

    /// Init with multiple parameters.
    init(a: Int, b: Int, c: Int? = nil) {
        self.number = b
    }

    func setNumber(value: Int? = nil) {
        number = value
    }
    
    func getNumber() -> Int {
        number ?? -1
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
    static let pyType: PyType = .make("TestClass", module: py.getmodule("__main__")) { type in
        type.magic("__new__") { __new__($1) }
        type.function("__init__(self) -> None") { __init__($1, TestClass.init) }
        type.function("__init__(self, number: int) -> None") { argc, argv in
            __init__(argc, argv, TestClass.init(number:))
        }
        type.function("__init__(self, a: int, b: int, c: int | None = None) -> None") { argc, argv in
            PyBind.function(argc, argv, TestClass.init(a:b:c:))
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
        type.staticmethod("static_func(value: int) -> TestClass") { argc, argv in
            PyBind.function(argc, argv, staticFunc)
        }
        type.staticmethod("async_create() -> TestClass") { argc, argv in
            PyBind.function(argc, argv, asyncCreate)
        }

        let typeObject = PyObject(type)

        typeObject.text = text
        
        typeObject._interface = #"""
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
            def set_number(self, value: int) -> None: ...
            def get_number(self) -> int: ...
            @staticmethod
            def static_func(value: int) -> TestClass: ...
        """#
    }
}

@MainActor
struct PythonConvertibleClassTests {
    let main = py.main
    let type = TestClass.pyType
    
    @Test func returnCachedFromToPython() throws {
        let obj = TestClass(number: 12)
        
        #expect(obj._pythonCache.reference == nil)
        
        main.test3 = obj
        
        Interpreter.run("test3.number")
        #expect(obj._pythonCache.reference != nil)
        
        // Uses cache.
        main.test4 = obj
                
        Interpreter.run("del test3")
        try py.module("gc")?.collect?()
        #expect(obj._pythonCache.reference != nil)
        
        Interpreter.run("del test4")
        try py.module("gc")?.collect?()
        #expect(obj._pythonCache.reference == nil)
    }
    
    @Test func classAttribute() {
        #expect(main.TestClass?.text == "Hello")
    }
    
    @Test func createFromPython() throws {
        Interpreter.run("""
        init_with_number = TestClass(12)
        TestClass_init = TestClass()
        """)
        #expect(main.init_with_number?.number == 12)
        let TestClass_init = try #require(main.TestClass_init)
        #expect(TestClass_init.number == nil)
        
    }
    
    @Test func pythonMutation() {
        let obj = TestClass(number: 32)
        main.test4 = obj

        main.test4?.number = "asd"
        #expect(obj.number == 32)
        
        main.test4?.number = 42
        #expect(obj.number == 42)
    }
    
    @Test func functionBinding() throws {
        let obj = TestClass(number: 32)
        main.test5 = obj
        try main.test5?.set_number?(10)
        #expect(obj.number == 10)
        
        try main.test5?.set_number?(nil)
        #expect(obj.number == nil)
    }
    
    @Test func getNumber() throws {
        let obj = TestClass(number: 32)
        main.test6 = obj
        
        try #expect(main.test6?.get_number?() == 32)
    }

    @Test func repr() throws {
        let obj = TestClass(number: 32)
        main.test7 = obj
        try #expect(main.test7?.__repr__?() == obj.description)
    }
    
    @Test func staticFunc() throws {
        let static_func = try #require(main.TestClass?.static_func)
        let result: TestClass = try #require(try static_func(10))

        #expect(result.number == 10)
    }
    
    @Test func asyncStaticFunc() async throws {
        await Interpreter.asyncRun("""
        test9 = await TestClass.async_create()
        """)

        #expect(main.test9?.number == 10)
    }
    
    @Test func intefaceTest() throws {
        let testClassType = PyObject(TestClass.pyType)
        let interface: String = try #require(testClassType._interface)
        
        #expect(interface.contains("TestClass(builtins.object)"))
    }
}
