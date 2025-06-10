//
//  BindInterfacesTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-02.
//

import Testing
import SwiftPy

@MainActor
extension PyAPI.Reference {
    static let test = Interpreter.module("test") ?? .main
}

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
        Interpreter.bindModule("test", [
            TestClass3.self,
            TestClass4.self
        ])
    }
    
    @Test func helpOnModule() throws {
        Interpreter.run("""
        import test
        help(test)
        """)

        let doc: String = try #require(
            Interpreter.evaluate("test.__doc__")
        )

        #expect(doc.contains("TestClass3"))
        #expect(doc.contains("TestClass4"))
    }
}
