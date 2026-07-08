//
//  PyWrapsTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-08.
//

import Testing
import SwiftPy

@MainActor
struct PyWrapsTests {
    // MARK: - default: positional args (kind 0/1)

    @Test func positionalForwarding() {
        Interpreter.run("""
        import functools

        def add(a: int, b: int) -> int:
            return a + b

        @functools.wraps(add)
        def wrapper(*args, **kwargs):
            return add(*args, **kwargs) + 100

        wraps_positional = wrapper(3, 4)
        """)

        #expect(py.main.wraps_positional == 107)
    }

    // MARK: - case 2: *args tuple unpacking

    @Test func varArgsForwarding() {
        Interpreter.run("""
        import functools

        def sumall(*args: int) -> int:
            return sum(args)

        @functools.wraps(sumall)
        def wrapper(*wargs, **kwargs):
            return sumall(*wargs) + 100

        wraps_varargs = wrapper(1, 2, 3)
        """)

        #expect(py.main.wraps_varargs == 106)
    }

    // MARK: - case 4: **kwargs dict forwarding

    @Test func varKwargsForwarding() {
        Interpreter.run("""
        import functools

        def merge(**kwargs: int) -> int:
            return kwargs.get("x", 0) + kwargs.get("y", 0)

        @functools.wraps(merge)
        def wrapper(*args, **kwargs):
            return merge(**kwargs) + 100

        wraps_varkwargs = wrapper(x=1, y=2)
        """)

        #expect(py.main.wraps_varkwargs == 103)
    }

    @Test func fallbackForwarding() {
        py.main.def("wraps_native(x: int) -> int") { argc, argv in
            PyBind.function(argc, argv) { (x: Int) in x * 2 }
        }

        Interpreter.run("""
        import functools

        @functools.wraps(wraps_native)
        def wrapper(*args, **kwargs):
            return wraps_native(*args, **kwargs) + 1

        wraps_fallback = wrapper(5)
        """)

        #expect(py.main.wraps_fallback == 11)
    }

    // MARK: - Metadata propagation

    @Test func nameIsPropagated() {
        Interpreter.run("""
        import functools

        def original_func() -> None:
            pass

        @functools.wraps(original_func)
        def wrapper(*args, **kwargs):
            pass

        wraps_name = wrapper.__name__
        """)

        #expect(py.main.wraps_name == "original_func")
    }

    @Test func wrappedAttributeIsSet() {
        Interpreter.run("""
        import functools

        def original_func() -> None:
            pass

        @functools.wraps(original_func)
        def wrapper(*args, **kwargs):
            pass

        wraps_is_same = wrapper.__wrapped__ is original_func
        """)

        #expect(py.main.wraps_is_same == true)
    }
}
