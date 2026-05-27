//
//  PyBind.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-07.
//

@MainActor
public enum PyBind {
    public static func module(_ name: String, block: @escaping (PyModule) -> Void) {
        Interpreter.shared.moduleBuilders[name] = { module in
            guard let module = PyModule(module) else { return }
            
            block(module)

            if let content = Interpreter.importFromSource(name: name + ".py") {
                _ = try? py.exec(source: content, filename: name, mode: .execution, module: module.reference)
            }

            // Add module.__doc__.
            _ = try? py.module("interpreter")?.bind_interfaces?(module)
        }
    }

    /// `() -> Void`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor () throws -> Void
    ) -> Bool {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            try fn()
            return .none
        }
    }
    
    /// `() async -> Void`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor @escaping () async throws -> Void
    ) -> Bool {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
        }
    }

    /// `() -> Any`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor () throws -> (any PythonConvertible)
    ) -> Bool {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return try fn()
        }
    }

    /// `() async -> Any`
    @inlinable
    public static func function<Result: PythonConvertible>(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor @escaping () async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
        }
    }

    /// `(...) -> Void`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor (repeat each Arg) throws -> Void
    ) -> Bool {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            try fn(repeat (each arguments))
            return .none
        }
    }

    /// `(...) async -> Void`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Void
    ) -> Bool {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return AsyncTask {
                try await fn(repeat (each arguments))
            }
        }
    }

    /// `(...) -> Any`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor (repeat each Arg) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return try fn(repeat (each arguments))
        }
    }
    
    /// `(...) async -> Any`
    @inlinable
    public static func function<
        each Arg: PythonConvertible,
        Result: PythonConvertible
    >(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return AsyncTask {
                try await fn(repeat (each arguments))
            }
        }
    }
}

// MARK: - Argument checkers.

extension PyBind {
    @inline(__always)
    public static func checkArgCount(_ got: Int32, expected: Int) throws(PythonError) {
        if expected != got {
            throw .argCountError(got, expected: expected)
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
        argv: PyRef?,
        from offset: Int = 0
    ) throws(PythonError) -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        var index: Int { defer { i += 1 }; return i }

        let arguments = try (repeat (each Arg).cast(argv, index))
        return arguments
    }
    
    /// Casts multiple generic ``PythonConvertible`` types with argument count checking,
    ///
    /// - Parameters:
    ///   - argc: Argument count.
    ///   - argv: Pointer to the first argument.
    ///   - offset: Initial index offset.
    /// - Returns: An array of casted arguments.
    @inlinable
    public static func castArgs<each Arg: PythonConvertible>(
        argc: Int32,
        argv: PyRef?,
        from offset: Int = 0
    ) throws(PythonError) -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        func index() throws(PythonError) -> Int {
            defer { i += 1 }
            if i >= argc {
                throw .TypeError("Expected more arguments, got \(argc)")
            }
            return i
        }

        let result = try (repeat (each Arg).cast(argv, index()))
        try checkArgCount(argc, expected: i)
        return result
    }
}

// MARK: - Legacy PyBind

extension PyBind {
    public static func module(_ name: String, _ types: [PythonBindable.Type], block: @escaping (PyRef?) -> Void = { _ in }) {
        Interpreter.moduleBuilders[name] = { module in
            guard let module = PyModule(module) else { return }
            // Set types.
            for type in types {
                let pyType = type.pyType
                module[dynamicMember: pyType.name] = py.tpobject(pyType)
            }

            // Load source.
            if let content = Interpreter.importFromSource(name: name + ".py") {
                _ = try? py.exec(source: content, filename: name, mode: .execution, module: module.reference)
            }

            block(module.reference)
            
            // Add module.__doc__.
            _ = try? py.module("interpreter")?.bind_interfaces?(module.reference)
        }
    }
}
