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
            var intProperty: Int = 10
        }
        """,
        expandedSource:
        #"""
        class TestClass {
            var intProperty: Int = 10

            var _pythonCache = PythonBindingCache()
        }

        extension TestClass: PythonBindable {
            static let pyType: PyType = .make("TestClass") { type in
                type.property(
                    "int_property",
                    getter: {
                        _bind_getter(\.intProperty, $1)
                    },
                    setter: {
                        _bind_setter(\.intProperty, $1)
                    }
                )
            }
        }
        """#,
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
            expandedSource: #"""
            class TestClass {
                var intProperty: Int { 10 }

                var _pythonCache = PythonBindingCache()
            }

            extension TestClass: PythonBindable {
                static let pyType: PyType = .make("TestClass") { type in
                    type.property(
                        "int_property",
                        getter: {
                            _bind_getter(\.intProperty, $1)
                        },
                        setter: nil
                    )
                }
            }
            """#,
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
                static let pyType: PyType = .make("TestClass") { type in
                    type.function("test_function(self) -> None") {
                        _bind_function(testFunction, $1)
                    }
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
            static let pyType: PyType = .make("TestClass") { type in
                type.function("test_function(self) -> int") {
                    _bind_function(testFunction, $1)
                }
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
            static let pyType: PyType = .make("TestClass") { type in
                type.function("test_function(self, value: str, val2: int) -> int") {
                    _bind_function(testFunction, $1)
                }
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
            static let pyType: PyType = .make("TestClass2", base: .object, module: .module) { type in
        
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
            static let pyType: PyType = .make("TestClass", base: .object, module: .module) { type in
        
            }
        }
        """,
        macros: testMacros)

    }
}
