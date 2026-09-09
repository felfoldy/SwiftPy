//
//  PyBind+SwiftPy.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import PocketPython
import Foundation

// Module registration needs `Interpreter`, and every async overload needs
// `AsyncTask` — both live above the low-level layer.
public extension PyBind {
    /// Registers a native module that is configured in Swift when the module
    /// is first imported.
    ///
    /// Use the `block` to populate the module with functions, types, and
    /// other bindings.
    ///
    /// ```swift
    /// PyBind.module("module") { module in
    ///     // Bind classes.
    ///     module.class(MyClass.self)
    ///
    ///     // Bind functions.
    ///     module.def("add(a: float, b: float) -> float") { argc, argv in
    ///         PyBind.function(argc, argv, add)
    ///     }
    ///
    ///     // Bind attributes.
    ///     module.VERSION = "1.0.1"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name the module is imported under in Python.
    ///   - docs: Optional module documentation exposed as `module.__doc__`.
    ///   - block: A closure that configures the ``PyModule`` with its bindings.
    static func module(_ name: String, docs: String? = nil, block: @escaping (PyModule) -> Void) {
        Interpreter.shared.bindModule(name, docs: docs, block: block)
    }

    /// Registers a source-only module whose body is loaded from `<name>.py`
    /// in the given bundle when the module is first imported.
    ///
    /// ```swift
    /// PyBind.module("module", in: .module)
    /// ```
    static func module(_ name: String, in bundle: Bundle) {
        Interpreter.shared.bindModule(name, in: bundle)
    }

    /// `() async -> Void`
    @inlinable
    static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor @escaping () async throws -> Void
    ) -> Bool {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
        }
    }

    /// `() async -> Any`
    @inlinable
    static func function<Result: PythonConvertible>(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor @escaping () async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
        }
    }

    /// `(...) async -> Void`
    @inlinable
    static func function<each Arg: PythonConvertible>(
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

    /// `(...) async -> Any`
    @inlinable
    static func function<
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
