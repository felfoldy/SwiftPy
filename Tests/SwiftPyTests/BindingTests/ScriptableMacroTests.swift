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
            let number = 10
        }
        """,
        expandedSource:
        """
        class TestClass {
            let number = 10

            private(set) var _cachedPythonReference: PyAPI.Reference?
        }

        extension TestClass: PythonConvertible {
            static let pyType: PyType = .make("TestClass") { userdata in

            }
        }
        """,
        macros: testMacros)
    }
}
