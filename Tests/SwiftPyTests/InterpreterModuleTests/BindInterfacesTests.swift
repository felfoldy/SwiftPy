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

@Scriptable
class MarkedTestClass {
    // MARK: - State

    /// A marked property.
    var count: Int = 0

    // MARK: - Lifecycle

    /// A marked init.
    init() {}

    // MARK: - Actions

    /// A marked method.
    func act() {}
}

@MainActor
@Suite(.serialized)
struct BindInterfacesTests {
    init() async {
        await Interpreter.run("import interpreter")

        PyBind.module("test") { test in
            test.classes(
                TestClass3.self,
                TestClass4.self,
                MarkedTestClass.self
            )
        }

        PyBind.module("documented_test", docs: "Documented test module.") { test in
            test.classes(TestClass3.self)
        }
    }
    
    @Test("keeps the docs a MARK comment is written above")
    func docsBelowMark() async throws {
        await Interpreter.run("""
        import test
        _marked_docs = [test.MarkedTestClass.act.__doc__, test.MarkedTestClass.count.__doc__, test.MarkedTestClass.__init__.__doc__]
        """)

        #expect(Interpreter.evaluate("_marked_docs[0]") == "A marked method.")
        #expect(Interpreter.evaluate("_marked_docs[1]") == "A marked property.")
        let initializer: String? = Interpreter.evaluate("_marked_docs[2]")
        #expect(initializer?.contains("A marked init.") == true)
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
