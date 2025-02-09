//
//  RegisterFunctionMacroTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-09.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftPyMacros
import XCTest

let testMacros: [String: Macro.Type] = [
    "def": RegisterFunctionMacro.self
]

class RegisterFunctionMacroTests: XCTestCase {
    func testRegisterFunctionMacro() async throws {
        assertMacroExpansion(
        """
        #def("macro") {
            print("macro")
        }
        """,
        expandedSource:
        """
        """,
        macros: testMacros)
    }
}


