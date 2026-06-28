// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import Foundation
import OSLog

let log = Logger(subsystem: "com.felfoldy.SwiftPy", category: "Interpreter")

/// Exposes a Swift class to Python.
///
/// Apply `@Scriptable` to a class to make it usable from Python. The macro conforms the type
/// to ``PythonBindable`` and binds its initializer, stored and computed properties, and
/// methods.
///
/// ```swift
/// @Scriptable
/// final class Counter {
///     var count: Int = 0
///
///     init() {}
///
///     func increment(by amount: Int) {
///         count += amount
///     }
/// }
/// ```
///
/// Register the type in a module with ``PyModule/class(_:)`` to make it importable. See
/// <doc:CreatingModules> for the full workflow.
///
/// - Parameters:
///   - name: The name the type is exposed as in Python. Defaults to the Swift type name.
///   - base: The Python base type to inherit from. Defaults to `object`.
///   - convertsToSnakeCase: Whether member names are converted to `snake_case`. Defaults to `true`.
@attached(member, names: named(_pythonCache))
@attached(extension, conformances: PythonBindable, names: named(pyType))
public macro Scriptable(
    _ name: String? = nil,
    base: PyType? = nil,
    convertsToSnakeCase: Bool = true
) = #externalMacro(module: "SwiftPyMacros", type: "ScriptableMacro")
