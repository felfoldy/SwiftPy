//
//  PyBind.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-07.
//

import pocketpy

@MainActor
public enum PyBind {
    /// Registers a new Python module by binding Swift types and loading optional source code.
    ///
    /// - Parameters:
    ///   - name: The name of the module to register.
    ///   - types: An array of types conforming to ``PythonBindable`` to expose to Python.
    ///
    /// This function enables dynamic module creation by:
    /// 1. Registering Swift types as Python classes.
    /// 2. Optionally loading and executing a `.py` file with the same name from ``bundles``.
    /// 3. Setting module-level metadata such as documentation.
    ///
    /// ### Example:
    /// ```swift
    /// PyBind.module("my_module", [MySwiftClass.self])
    /// ```
    /// This exposes `MySwiftClass` to Python and runs `my_module.py` if found in the app bundle.
    public static func module(_ name: String, _ types: [PythonBindable.Type], block: @escaping (PyAPI.Reference?) -> Void = { _ in }) {
        Interpreter.moduleBuilders[name] = { module in
            guard let module = PyModule(module) else { return }
            // Set types.
            for type in types {
                let pyType = type.pyType
                module[dynamicMember: pyType.name] = py.tpobject(pyType)
            }

            // Load source.
            if let content = Interpreter.importFromBundle(name: name + ".py") {
                try? Interpreter.printErrors {
                    py.exec(source: content, filename: name, mode: .execution, module: module.reference)
                }
            }

            block(module.reference)
            
            // Add module.__doc__.
            try? PyModule("interpreter")?.bind_interfaces?(module.reference)
        }
    }
    
    public static func module(_ name: String, block: @escaping (PyModule) -> Void) {
        Interpreter.shared.moduleBuilders[name] = { module in
            guard let module = PyModule(module) else { return }
            
            block(module)

            if let content = Interpreter.importFromBundle(name: name + ".py") {
                try? Interpreter.printErrors {
                    py.exec(source: content, filename: name, mode: .execution, module: module.reference)
                }
            }

            // Add module.__doc__.
            try? PyModule("interpreter")?.bind_interfaces?(module.reference)
        }
    }
    
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
    
    /// `() async -> Void`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyAPI.Reference?,
        _ fn: @MainActor @escaping () async throws -> Void
    ) -> Bool {
        PyAPI.returnOrThrow {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
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

    /// `() async -> Any`
    @inlinable
    public static func function<Result: PythonConvertible>(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyAPI.Reference?,
        _ fn: @MainActor @escaping () async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.returnOrThrow {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
        }
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

    /// `(...) async -> Void`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyAPI.Reference?,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Void
    ) -> Bool {
        PyAPI.returnOrThrow {
            let arguments = try checkArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return AsyncTask {
                try await fn(repeat (each arguments))
            }
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
    
    /// `(...) async -> Any`
    @inlinable
    public static func function<
        each Arg: PythonConvertible,
        Result: PythonConvertible
    >(
        _ argc: Int32,
        _ argv: PyAPI.Reference?,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.returnOrThrow {
            let arguments = try checkArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return AsyncTask {
                try await fn(repeat (each arguments))
            }
        }
    }
}
