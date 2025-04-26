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

let testMacros: [String: Macro.Type] = [
    "Scriptable": ScriptableMacro.self
]

class ScriptableMacroTests: XCTestCase {
    func testPropertyBinding() {
        assertMacroExpansion(
        """
        @Scriptable
        class TestClass {
            let listProperty: [String] = []
            var intProperty: Int = 10
            var dictionary: [String: Float] = [:]
        }
        """,
        expandedSource:
        """
        class TestClass {
            let listProperty: [String] = []
            var intProperty: Int = 10
            var dictionary: [String: Float] = [:]

            var _pythonCache = PythonBindingCache()
        }

        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                \(property("listProperty", python: "list_property", setter: false))
                \(property("intProperty", python: "int_property"))
                \(property("dictionary", python: "dictionary"))
                \(newAndRepr)
                \(interfaceBegin)
                    class TestClass:
                        list_property: list[str]
                        int_property: int
                        dictionary: dict[str, float]
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testComputedProperty() {
        assertMacroExpansion(
            """
            @Scriptable
            class TestClass {
                var intProperty: Int { 10 }
            }
            """,
            expandedSource: """
            class TestClass {
                var intProperty: Int { 10 }

                var _pythonCache = PythonBindingCache()
            }

            extension TestClass: PythonBindable {
                @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                    \(property("intProperty", python: "int_property", setter: false))
                    \(newAndRepr)
                    \(interfaceBegin)
                        class TestClass:
                            int_property: int
                    \(interfaceEnd)
                }
            }
            """,
            macros: testMacros)
    }
    
    func testMethodBinding() {
        assertMacroExpansion(
            """
            @Scriptable
            class TestClass {
                func testFunction() {}
            }
            """,
            expandedSource:"""
            class TestClass {
                func testFunction() {}

                var _pythonCache = PythonBindingCache()
            }

            extension TestClass: PythonBindable {
                @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                    type.function("test_function(self) -> None") {
                        _bind_function($1, testFunction)
                    }
                    \(newAndRepr)
                    \(interfaceBegin)
                        class TestClass:
                            def test_function(self) -> None: ...
                    \(interfaceEnd)
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testFunctionBinding() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            func testFunction() -> Int { 10 }
        }
        """, expandedSource: """
        class TestClass {
            func testFunction() -> Int { 10 }
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                type.function("test_function(self) -> int") {
                    _bind_function($1, testFunction)
                }
                \(newAndRepr)
                \(interfaceBegin)
                    class TestClass:
                        def test_function(self) -> int: ...
                \(interfaceEnd)
            }
        }
        """,
        macros: testMacros)
    }
    
    func testFunctionWithOneParameter() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            func testFunction(_ value: String, val2: Int) -> Int { 10 }
        }
        """, expandedSource: """
        class TestClass {
            func testFunction(_ value: String, val2: Int) -> Int { 10 }
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                type.function("test_function(self, value: str, val2: int) -> int") {
                    _bind_function($1, testFunction)
                }
                \(newAndRepr)
                \(interfaceBegin)
                    class TestClass:
                        def test_function(self, value: str, val2: int) -> int: ...
                \(interfaceEnd)
            }
        }
        """, macros: testMacros)
    }
    
    func testScriptableAttributes() {
        // Without overriden type name.
        assertMacroExpansion("""
        @Scriptable("TestClass2", base: .object, module: .module)
        class TestClass {}
        """, expandedSource: """
        class TestClass {
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass2", base: .object, module: .module) { type in
        
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
        @Scriptable(base: .object, module: .module)
        class TestClass {}
        """, expandedSource: """
        class TestClass {
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: .module) { type in
        
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
    
    func testInit() {
        assertMacroExpansion("""
        @Scriptable
        class TestClass {
            init() {}
            init(number: Int) {}
        }
        """, expandedSource: """
        class TestClass {
            init() {}
            init(number: Int) {}
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                type.magic("__init__") { argc, argv in
                    __init__(argc, argv, TestClass.init) ||
                    __init__(argc, argv, TestClass.init(number:)) ||
                    PyAPI.throw(.TypeError, "Invalid arguments")
                }
                \(newAndRepr)
                \(interfaceBegin)
                    class TestClass:
                        def __init__(self, *args, **kwargs) -> None: ...
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
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
        
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
        }
        """, expandedSource: """
        class TestClass {
            static func testFunction() -> Int { 10 }
        
            var _pythonCache = PythonBindingCache()
        }
        
        extension TestClass: PythonBindable {
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                type.staticFunction("test_function") { argc, argv in
                    _bind_staticFunction(argc, argv, testFunction)
                }
                \(newAndRepr)
                \(interfaceBegin)
                    class TestClass:
                        @staticmethod
                        def test_function() -> int: ...
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
            @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
        
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
    
    func testOptionals() {
        assertMacroExpansion("""
            @Scriptable
            class TestClass {
                var number: Int?
                func doSomething() -> Int? {}
            }
            """, expandedSource: """
            class TestClass {
                var number: Int?
                func doSomething() -> Int? {}
            
                var _pythonCache = PythonBindingCache()
            }
            
            extension TestClass: PythonBindable {
                @MainActor static let pyType: PyType = .make("TestClass", base: .object, module: Interpreter.main) { type in
                    \(property("number", python: "number"))
                    type.function("do_something(self) -> int | None") {
                        _bind_function($1, doSomething)
                    }
                    \(newAndRepr)
                    \(interfaceBegin)
                        class TestClass:
                            number: int | None
                            def do_something(self) -> int | None: ...
                    \(interfaceEnd)
                }
            }
            """,
            macros: testMacros
        )
    }
}

private func property(_ name: String, python: String, setter: Bool = true) -> String {
    if setter {
    """
    type.property(
                "\(python)",
                getter: {
                    _bind_getter(\\.\(name), $1)
                },
                setter: {
                    _bind_setter(\\.\(name), $1)
                }
            )
    """
    } else {
    """
    type.property(
                "\(python)",
                getter: {
                    _bind_getter(\\.\(name), $1)
                },
                setter: nil
            )
    """
    }
}

private var newAndRepr: String {
    """
    type.magic("__new__") {
                __new__($1)
            }
            type.magic("__repr__") {
                __repr__($1)
            }
    """
}

private var interfaceBegin: String {
    [
        #"type.object?.setAttribute("_interface","#,
        "            #\"\"\"",
    ].joined(separator: "\n")
}

private var interfaceEnd: String {
    [
        "    \"\"\"#",
        "            .toRegister(0)",
        "        )"
    ]
    .joined(separator: "\n")
}
