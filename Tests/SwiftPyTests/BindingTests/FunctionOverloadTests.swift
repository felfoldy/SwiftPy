//
//  FunctionOverloadTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-05-31.
//

import SwiftPy
import Testing

extension PythonValueBindable {
    typealias Variadic = Array
}

private class SUT: PythonBindable {
    var member: String?
    
    init() { member = nil }
    
    init(keyword: String? = nil) throws {
        if keyword == "bad" {
            throw PythonError.NameError("Bad argument")
        }
        self.member = keyword
    }

    func update(number: Int) throws {
        member = String(number)
    }

    func update(member: String? = nil) {
        self.member = member
    }
    
    func update(asAsync: Bool) async {
        self.member = "async"
    }
    
    static func make(number: Int) -> String {
        "number \(number)"
    }

    static func make(member: String? = nil) -> String {
        member ?? "none"
    }

    var _pythonCache = PythonBindingCache()
}

extension SUT {
    static let pyType = PyType.make(
        "SUT",
        base: .object
    ) { type in
        type.function("__new__(cls, *args, **kwargs)") {
            __new__($1)
        }
        type.function("__init__(self) -> None") {
            __init__($1, SUT.init)
        }
        type.function("__init__(self, keyword: str | None = None) -> None") {
            __init__($1, SUT.init(keyword:))
        }
        type.function("update(self, member: str | None = None) -> None") {
            _bind_function($1, update(member:))
        }
        type.function("update(self, number: int) -> None") {
            _bind_function($1, update(number:))
        }
        type.function("update(self, as_async: bool) -> None") {
            _bind_function($1, update(asAsync:))
        }
        type.staticmethod("make(member: str | None = None) -> str") {
            PyBind.function($0, $1, make(member:))
        }
        type.staticmethod("make(number: int) -> str") {
            PyBind.function($0, $1, make(number:))
        }
        type.property(
            "member",
            getter: {
                _bind_getter(\.member, $1)
            },
            setter: {
                _bind_setter(\.member, $1)
            }
        )
    }
}

@MainActor
struct FunctionOverloadTests {
    init() {
        PyBind.module("FunctionOverloadTests") { module in
            module.class(SUT.self)
        }

        Interpreter.run("from FunctionOverloadTests import SUT")
    }
    
    @Test(arguments: [
        ("sut = SUT(keyword='test')", "test"),
        ("sut = SUT()", String?.none),
        ("sut = SUT('test')", "test"),
    ])
    func initOverloading(script: String, member: String?) throws {
        Interpreter.run(script)
        let sut: SUT = try #require(py.main.sut)
        #expect(sut.member == member)
    }
    
    @Test
    func initBodyErrorIsPropagated() throws {
        Interpreter.run("""
        sut = None
        try:
            sut = SUT(keyword='bad')
            error_type = None
            error_message = None
        except Exception as error:
            error_type = type(error).__name__
            error_message = str(error)
        """)

        let sut: SUT? = py.main.sut
        #expect(sut == nil)
        #expect(py.main.error_type == "NameError")

        let message: String = try #require(py.main.error_message)
        #expect(message.contains("Bad argument"))
        #expect(!message.contains("no matching overload"))
    }
    
    @Test(arguments: [
        ("sut.update(42)", "42"),
        ("sut.update(member='hello')", "hello"),
        ("sut.update('hello')", "hello"),
        ("sut.update()", String?.none),
    ])
    func functionOverload(script: String, member: String?) throws {
        Interpreter.run("""
        sut = SUT()
        \(script)
        """)

        let sut: SUT = try #require(py.main.sut)
        #expect(sut.member == member)
    }
    
    @Test func asyncFunctionOverload() async throws {
        await Interpreter.asyncRun("""
        sut = SUT()
        await sut.update(True)
        """)

        let sut: SUT = try #require(py.main.sut)
        #expect(sut.member == "async")
    }

    @Test
    func functionOverloadBodyErrorIsPropagated() throws {
        Interpreter.run("""
        sut = SUT()
        try:
            sut.update(1, 2, 3)
            error_type = None
            error_message = None
        except Exception as error:
            error_type = type(error).__name__
            error_message = str(error)
        """)

        #expect(py.main.error_type == "TypeError")

        let message: String = try #require(py.main.error_message)
        #expect(message.contains("no matching overload"))
    }

    @Test(arguments: [
        // ("result = SUT.make(7)", "number 7"),
        ("result = SUT.make(member='hello')", "hello"),
        ("result = SUT.make('hello')", "hello"),
        ("result = SUT.make()", "none"),
    ])
    func staticMethodOverload(script: String, result: String) throws {
        withKnownIssue("static method overloading is not supported yet") {
            Interpreter.run(script)
            #expect(py.main.result == result)
        }
    }
}
