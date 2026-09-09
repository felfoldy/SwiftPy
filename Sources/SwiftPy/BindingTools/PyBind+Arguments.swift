//
//  PyBind+Arguments.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

// The argument marshalling: it goes through PyArguments and PyReturn only,
// so one copy serves both backends.
public extension PyBind {
    /// `() -> Void`
    @inlinable
    static func function(
        _ first: PyArguments.RawFirst,
        _ second: @autoclosure () -> PyArguments.RawSecond,
        _ fn: @MainActor () throws -> Void
    ) -> PyReturn {
        PyAPI.return {
            try checkArgCount(PyArguments(function: first, second()).count, expected: 0)
            try fn()
            return .none
        }
    }

    /// `() -> Any`
    @inlinable
    static func function(
        _ first: PyArguments.RawFirst,
        _ second: @autoclosure () -> PyArguments.RawSecond,
        _ fn: @MainActor () throws -> (any PythonConvertible)
    ) -> PyReturn {
        PyAPI.return {
            try checkArgCount(PyArguments(function: first, second()).count, expected: 0)
            return try fn()
        }
    }

    /// `(...) -> Void`
    @inlinable
    static func function<each Arg: PythonConvertible>(
        _ first: PyArguments.RawFirst,
        _ second: PyArguments.RawSecond,
        _ fn: @MainActor (repeat each Arg) throws -> Void
    ) -> PyReturn {
        PyAPI.return {
            let arguments = try castArgs(PyArguments(function: first, second)) as (repeat (each Arg))
            try fn(repeat (each arguments))
            return .none
        }
    }

    /// `(...) -> Any`
    @inlinable
    static func function<each Arg: PythonConvertible>(
        _ first: PyArguments.RawFirst,
        _ second: PyArguments.RawSecond,
        _ fn: @MainActor (repeat each Arg) throws -> any PythonConvertible
    ) -> PyReturn {
        PyAPI.return {
            let arguments = try castArgs(PyArguments(function: first, second)) as (repeat (each Arg))
            return try fn(repeat (each arguments))
        }
    }

}

public extension PyBind {
    @inline(__always)
    static func checkArgCount(_ got: Int, expected: Int) throws(PythonError) {
        if expected != got {
            throw .argCountError(got, expected: expected)
        }
        overloadArgumentsMatched = true
    }
    
    /// Reads a call's arguments into a typed tuple. Backend-agnostic: it only
    /// goes through ``PyArguments``.
    @inlinable
    static func castArgs<each Arg: PythonConvertible>(
        _ arguments: PyArguments,
        from offset: Int = 0
    ) throws(PythonError) -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        func index() throws(PythonError) -> Int {
            defer { i += 1 }
            if i >= arguments.count {
                throw .TypeError("Expected more arguments, got \(arguments.count)")
            }
            return i
        }

        let result = try (repeat (each Arg).cast(arguments, index()))
        try checkArgCount(arguments.count, expected: i)
        return result
    }
}
