//
//  PyModuleTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-15.
//

import Testing
import SwiftPy

@MainActor
@Suite(.serialized)
struct PyModuleTests {
    init() {
        PyBind.module("module_handle_test") { module in
            module.first = "1"
            module.second = "2"
            module.third = "3"
            let none: PyObject? = nil
            module.none = none
        }
    }

    /// A handle taken on the first import must survive the calls that follow,
    /// even though the import itself answers with the shared return register.
    @Test func handleStaysValidAfterImport() {
        let module = py.module("module_handle_test")

        #expect(module?.first == "1")
        #expect(module?.second == "2")
        #expect(module?.third == "3")
    }

    @Test func pythonNoneAttributeReturnsNil() {
        let none: PyObject? = py.module("module_handle_test")?.none
        #expect(none == nil)
    }

    @Test func missingModuleReturnsNil() {
        #expect(py.module("no_such_module_here") == nil)
    }
}
