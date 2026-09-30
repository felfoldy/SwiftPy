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
@Suite(.serialized)
struct BindInterfacesTests {
    init() async {
        await Interpreter.run("import interpreter")

        PyBind.module("test") { test in
            test.classes(
                TestClass3.self,
                TestClass4.self
            )
        }

        PyBind.module("documented_test", docs: "Documented test module.") { test in
            test.classes(TestClass3.self)
        }
    }
    
    @Test func helpOnModule() async throws {
        await Interpreter.run("""
        import builtins as _b
        import test
        _test_help_cap = []
        _test_help_orig = _b.print
        def _test_help_cp(msg=''):
            _test_help_cap.append(str(msg))
        _b.print = _test_help_cp
        help(test)
        _b.print = _test_help_orig
        _test_help_out = "\\n".join(_test_help_cap)
        """)

        let output: String = try #require(Interpreter.evaluate("_test_help_out"))
        #expect(output.contains("TestClass3"))
        #expect(output.contains("TestClass4"))
    }

    @Test func classReportsTheModuleRegisteringItFirst() async throws {
        await Interpreter.run("""
        import test, documented_test
        _class3_module = documented_test.TestClass3.__module__
        """)

        let module: String = try #require(Interpreter.evaluate("_class3_module"))
        #expect(module == "test")
    }

    @Test func moduleDocsParameterSetsDocstring() async throws {
        await Interpreter.run("""
        import documented_test
        _documented_test_doc = documented_test.__doc__
        """)

        let doc: String = try #require(Interpreter.evaluate("_documented_test_doc"))
        #expect(doc == "Documented test module.")
    }
}
