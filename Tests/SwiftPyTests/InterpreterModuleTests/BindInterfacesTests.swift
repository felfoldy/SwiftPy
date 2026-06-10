//
//  BindInterfacesTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-02.
//

import Testing
import SwiftPy

@Scriptable
class TestClass3 {}

/// Test Class 4.
@Scriptable
class TestClass4 {
    /// Description.
    func testMethod() {}
}

@MainActor
struct BindInterfacesTests {
    init() {
        PyBind.module("test") { test in
            test.classes(
                TestClass3.self,
                TestClass4.self
            )
        }
    }
    
    @Test func helpOnModule() throws {
        Interpreter.run("""
        import test
        help(test)
        """)

        let doc: String = try #require(
            py.main.test?.__doc__
        )

        #expect(doc.contains("TestClass3"))
        #expect(doc.contains("TestClass4"))
    }
}
