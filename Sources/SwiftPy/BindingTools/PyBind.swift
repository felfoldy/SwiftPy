//
//  PyBind.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-07.
//

@MainActor
public enum PyBind {
    @usableFromInline
    @inline(__always)
    static func checkArgCount(_ got: Int32, expected: Int) throws {
        if expected != got {
            throw PythonError.TypeError("expected \(expected) arguments, got \(got)")
        }
    }
    
    /// Casts multiple generic ``PythonConvertible`` types without argument count checking,
    ///
    /// - Parameters:
    ///   - argv: Pointer to the first argument.
    ///   - offset: Initial index offset.
    /// - Returns: An array of casted arguments.
    @inlinable
    public static func castArgs<each Arg: PythonConvertible>(
        argv: PyAPI.Reference?,
        from offset: Int = 0
    ) throws -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        var index: Int { defer { i += 1 }; return i }

        return try (repeat (each Arg).cast(argv, index))
    }
    
    /// Casts multiple generic ``PythonConvertible`` types with argument count checking,
    ///
    /// - Parameters:
    ///   - argc: Argument count.
    ///   - argv: Pointer to the first argument.
    ///   - offset: Initial index offset.
    /// - Returns: An array of casted arguments.
    @inlinable
    public static func checkArgs<each Arg: PythonConvertible>(
        argc: Int32,
        argv: PyAPI.Reference?,
        from offset: Int = 0
    ) throws -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        func index() throws -> Int {
            defer { i += 1 }
            if i >= argc {
                throw PythonError.ValueError("Expected more arguments, got \(argc)")
            }
            return i
        }

        let result = try (repeat (each Arg).cast(argv, index()))
        try checkArgCount(argc, expected: i)
        return result
    }

    /// `() -> Void`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyAPI.Reference?,
        _ fn: @MainActor () throws -> Void
    ) -> Bool {
        PyAPI.returnOrThrow {
            try checkArgCount(argc, expected: 0)
            return try fn()
        }
    }

    /// `() -> Any`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyAPI.Reference?,
        _ fn: @MainActor () throws -> (any PythonConvertible)
    ) -> Bool {
        PyAPI.returnOrThrow { try fn() }
    }
    
    /// `(...) -> Void`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyAPI.Reference?,
        _ arguments: @MainActor (repeat each Arg) throws -> Void
    ) -> Bool {
        PyAPI.returnOrThrow {
            let result = try checkArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return try arguments(repeat (each result))
        }
    }
    
    /// `(...) -> Any`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyAPI.Reference?,
        _ arguments: @MainActor (repeat each Arg) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.returnOrThrow {
            let result = try checkArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return try arguments(repeat (each result))
        }
    }
}
