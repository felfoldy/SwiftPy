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
    func testRegisterFunctionMacro() {
        assertMacroExpansion(
        """
        @Scriptable
        class TestClass {
            var intProperty: Int = 10
        }
        """,
        expandedSource:
        """
        class TestClass {
            var intProperty: Int = 10

            var _cachedPythonReference: PyAPI.Reference?
        }

        extension TestClass: PythonBindable {
            static let pyType: PyType = .make("TestClass") { userdata in
                deinitFromPython(userdata)
            } bind: { type in
                type.property(
                    "int_property",
                    getter: { _, argv in
                        return PyAPI.return(TestClass(argv)?.intProperty)
                    },
                    setter: { _, argv in
                    guard let value = Int(argv? [1]) else {
                        return PyAPI.throw(.TypeError, "Expected Int at position 1")
                    }
                    TestClass(argv)?.intProperty = value
                    return PyAPI.return(.none)
                    }
                )
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
            expandedSource:"""
            class TestClass {
                var intProperty: Int { 10 }

                var _cachedPythonReference: PyAPI.Reference?
            }

            extension TestClass: PythonBindable {
                static let pyType: PyType = .make("TestClass") { userdata in
                    deinitFromPython(userdata)
                } bind: { type in
                    type.property(
                        "int_property",
                        getter: { _, argv in
                            return PyAPI.return(TestClass(argv)?.intProperty)
                        },
                        setter: nil
                    )
                }
            }
            """,
            macros: testMacros)
    }
    
    func testFunctionBinding() {
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

                var _cachedPythonReference: PyAPI.Reference?
            }

            extension TestClass: PythonBindable {
                static let pyType: PyType = .make("TestClass") { userdata in
                    deinitFromPython(userdata)
                } bind: { type in
                    type.property(
                        "int_property",
                        getter: { _, argv in
                            return PyAPI.return(TestClass(argv)?.intProperty)
                        },
                        setter: nil
                    )
                }
            }
            """,
            macros: testMacros
        )
    }
}
