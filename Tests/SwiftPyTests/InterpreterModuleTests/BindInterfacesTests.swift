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

@MainActor
struct BindInterfacesTests {
    @Scriptable(module: .test)
    class TestClass3 {}
    
    /// Test Class 4.
    @Scriptable(module: .test)
    class TestClass4 {
        /// Description.
        func testMethod() {}
    }
    
    @Test func helpOnModule() throws {
        Interpreter.bindInterfaces(.test, [
            TestClass3.pyType,
            TestClass4.pyType
        ])
        
        Interpreter.run("""
        import test
        help(test)
        """)

        let doc = try #require(
            String(Interpreter.evaluate("test.__doc__"))
        )

        #expect(doc.contains("TestClass3"))
        #expect(doc.contains("TestClass4"))
    }
}
