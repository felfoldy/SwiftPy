//
//  ScriptableMacroTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-09.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftPyMacros
import XCTest

class ScriptableMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Scriptable": ScriptableMacro.self
    ]

    func testPropertyBinding() {
        assertMacroExpansion(
        """
        @Scriptable
        class TestClass {
            let listProperty: [String] = []
            var intProperty: Int? = 10
            var dictionary: [String: Float] { [:] }
            static let text: String = "Hello"
        }
        """,
        expandedSource:
        """
        class TestClass {
            let listProperty: [String] = []
            var intProperty: Int? = 10
            var dictionary: [String: Float] { [:] }
            static let text: String = "Hello"

            var _pythonCache = PythonBindingCache()
        }

        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
                \(property("listProperty", python: "list_property", setter: false))
                \(property("intProperty", python: "int_property"))
                \(property("dictionary", python: "dictionary", setter: false))
                PyObject(type).text = text
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    list_property: list[str]
                    int_property: int | None
                    dictionary: dict[str, float]
                    text: str
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testFunctionBinding() {
        assertMacroExpansion("""
        @Scriptable
        public class TestClass {
            func testMethod(arg: Int? = nil, arg2: String = "1") {}
            func testFunction(_ value: String, val2: Int) -> Int { 10 }
            func testAsync() async -> Int { 10 }
        }
        """, expandedSource: """
        public class TestClass {
            func testMethod(arg: Int? = nil, arg2: String = "1") {}
            func testFunction(_ value: String, val2: Int) -> Int { 10 }
            func testAsync() async -> Int { 10 }
        
            public var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor public static let pyType: PyType = .make("TestClass", base: .object) { type in
                \(function("testMethod(arg:arg2:)", "test_method(self, arg: int | None = None, arg2: str = '1') -> None"))
                \(function("testFunction(_:val2:)", "test_function(self, value: str, val2: int) -> int"))
                \(function("testAsync", "test_async(self) -> int"))
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    def test_method(self, arg: int | None = None, arg2: str = '1') -> None: ...
                    def test_function(self, value: str, val2: int) -> int: ...
                    async def test_async(self) -> int: ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testScriptableAttributes() {
        // Without overriden type name.
        assertMacroExpansion("""
        @Scriptable("TestClass2", base: .object)
        class TestClass {}
        """, expandedSource: """
        class TestClass {
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass2", base: .object) { type in
        
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass2:
                    ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
        
        // Without overriden type name.
        assertMacroExpansion("""
        @Scriptable(base: .object)
        class TestClass {}
        """, expandedSource: """
        class TestClass {
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
        
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testConvertsToSnakeCaseFalse() {
        // Without overriden type name.
        assertMacroExpansion("""
        @Scriptable(convertsToSnakeCase: false)
        class TestClass {
            let someVariable: Int
        }
        """, expandedSource: """
        class TestClass {
            let someVariable: Int
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
                \(property("someVariable", python: "someVariable", setter: false))
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    someVariable: int
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testInit() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            init() {}
            /// documents
            init(number: Int) {}
        }
        """, expandedSource: """
        class TestClass {
            init() {}
            /// documents
            init(number: Int) {}
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
                \(initializer("__init__(self) -> None", "TestClass.init"))
                \(initializer("__init__(self, number: int) -> None", "TestClass.init(number:)", docstring: "documents"))
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    @overload
                    def __init__(self) -> None: ...
                    @overload
                    def __init__(self, number: int) -> None:
                        \"""documents\"""
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }

    func testRedundantPythonBindable() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass: PythonBindable {}
        """, expandedSource: """
        class TestClass: PythonBindable {
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
        
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testStaticFunctionBinding() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            static func testFunction() -> Int { 10 }
            static func asyncFunction() async -> Int { 10 }
        }
        """, expandedSource: """
        class TestClass {
            static func testFunction() -> Int { 10 }
            static func asyncFunction() async -> Int { 10 }
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
                type.staticmethod("test_function() -> int") { argc, argv in
                    PyBind.function(argc, argv, testFunction)
                }
                type.staticmethod("async_function() -> int") { argc, argv in
                    PyBind.function(argc, argv, asyncFunction)
                }
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    @staticmethod
                    def test_function() -> int: ...
                    @staticmethod
                    async def async_function() -> int: ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testIgnoreInternalAndPrivate() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            private var number: Int = 10
            internal init() {}
            private func doSomething() {}
        }
        """, expandedSource: """
        class TestClass {
            private var number: Int = 10
            internal init() {}
            private func doSomething() {}

            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
        
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testDocstrings() {
        assertMacroExpansion("""
            /// Test description.
            @Scriptable
            class TestClass {
                /// A number.
                var number: Int
                /// Do something.
                func doSomething() -> Int {}
            }
            """, expandedSource: """
            /// Test description.
            class TestClass {
                /// A number.
                var number: Int
                /// Do something.
                func doSomething() -> Int {}
            
                var _pythonCache = PythonBindingCache()
            }
            
            extension TestClass: PythonBindable {
                @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
                    \(property("number", python: "number", docstring: "A number."))
                    type.function("do_something(self) -> int", #"Do something."#) {
                        _bind_function(PyArguments(method: $0, $1), doSomething)
                    }
                    \(newAndRepr)
                    \(interfaceBegin)
                    class TestClass:
                        \"""Test description.
            
                        Attributes:
                            number: A number.
                        \"""
            
                        number: int
            
                        def do_something(self) -> int:
                            \"""Do something.\"""
                    \(interfaceEnd)
                    PyObject(type).__doc__ = #\"""
                    Test description.
                    \"""#
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMultilineFunctionSignature() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            static func map(
                content: String? = nil
            ) -> TestClass {
                TestClass()
            }
        }
        """, expandedSource: """
        class TestClass {
            static func map(
                content: String? = nil
            ) -> TestClass {
                TestClass()
            }
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
                type.staticmethod("map(content: str | None = None) -> TestClass") { argc, argv in
                    PyBind.function(argc, argv, map(content:))
                }
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    @staticmethod
                    def map(content: str | None = None) -> TestClass: ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testViewBaseHidesBodyFromInterface() {
        assertMacroExpansion("""
        @Scriptable(base: .View)
        class TestClass {
            func body() -> AnyView {
                AnyView(EmptyView())
            }

            func update() {}
        }
        """, expandedSource: """
        class TestClass {
            func body() -> AnyView {
                AnyView(EmptyView())
            }

            func update() {}
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .View) { type in
                type.function("body(self) -> AnyView") {
                    _bind_function(PyArguments(method: $0, $1), body)
                }
                type.function("update(self) -> None") {
                    _bind_function(PyArguments(method: $0, $1), update)
                }
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass(View):
                    def update(self) -> None: ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }

    func testOverloadedFunctionBinding() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            func respond(_ prompt: String) -> String { "" }
            func respond(_ prompt: String, schema: PyObject) -> PyObject { prompt }
        }
        """, expandedSource: """
        class TestClass {
            func respond(_ prompt: String) -> String { "" }
            func respond(_ prompt: String, schema: PyObject) -> PyObject { prompt }

            var _pythonCache = PythonBindingCache()
        }

        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object) { type in
                type.function("respond(self, prompt: str) -> str") {
                    _bind_function(PyArguments(method: $0, $1), respond(_:))
                }
                type.function("respond(self, prompt: str, schema: Any) -> Any") {
                    _bind_function(PyArguments(method: $0, $1), respond(_:schema:))
                }
                \(newAndRepr)
                \(interfaceBegin)
                class TestClass:
                    def respond(self, prompt: str) -> str: ...
                    def respond(self, prompt: str, schema: Any) -> Any: ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
}

private func function(_ name: String, _ syntax: String) -> String {
    """
    type.function("\(syntax)") {
                _bind_function(PyArguments(method: $0, $1), \(name))
            }
    """
}

private func initializer(
    _ syntax: String,
    _ initializer: String,
    docstring: String? = nil
) -> String {
    let documented = docstring.map { ", #\"\($0)\"#" } ?? ""

    return """
    type.function("\(syntax)"\(documented)) {
                __init__(PyArguments(method: $0, $1), \(initializer))
            }
    """
}

private var newAndRepr: String {
    """
    type.function("__new__(cls, *args, **kwargs)") {
                __new__(PyArguments(method: $0, $1))
            }
            type.magic("__repr__") {
                __repr__(PyArguments(method: $0, $1))
            }
    """
}

private func property(
    _ name: String,
    python: String,
    setter: Bool = true,
    docstring: String? = nil
) -> String {
    let documented = docstring.map { ", #\"\($0)\"#" } ?? ""

    if setter {
    return """
    type.property(
                "\(python)"\(documented),
                getter: {
                    _bind_getter(\\.\(name), PyArguments(method: $0, $1))
                },
                setter: {
                    _bind_setter(\\.\(name), PyArguments(method: $0, $1))
                }
            )
    """
    } else {
    return """
    type.property(
                "\(python)"\(documented),
                getter: {
                    _bind_getter(\\.\(name), PyArguments(method: $0, $1))
                },
                setter: nil
            )
    """
    }
}

private let interfaceBegin: String = #"PyObject(type)._interface = #""""#

private let interfaceEnd: String = "\"\"\"#"
