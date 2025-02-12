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

class RegisterFunctionMacroTests: XCTestCase {
    func testRegisterFunctionMacro() async throws {
        assertMacroExpansion(
        """
        @Scriptable
        class TestClass {
            let intProperty: Int = 10
        }
        """,
        expandedSource:
        """
        class TestClass {
            let intProperty: Int = 10

            var _cachedPythonReference: PyAPI.Reference?
        }

        extension TestClass: PythonBindable {
            static let pyType: PyType = .make("TestClass") { userdata in
                deinitFromPython(userdata)
            } bind: { type in
                type.property(
                    "int_property",
                    getter: { _, argv in
                        PyAPI.return(TestClass(argv)?.intProperty)
                        return true
                    },
                    setter: nil
                )
            }
        }
        """,
        macros: testMacros)
    }
}
