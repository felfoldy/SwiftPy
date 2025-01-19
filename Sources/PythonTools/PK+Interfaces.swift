//
//  PK.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy

/// Namespace for pocketpy typealias/interfaces.
@MainActor
public enum PK {}

public extension PK {
    /// Python function signature `(argc: Int32, argv: StackRef?) -> Bool`.
    typealias CFunction = py_CFunction

    typealias Module = py_GlobalRef

    /// Sets the return value to None.
    @inlinable static func returnNone() {
        py_newnone(py_retval())
    }

    @inlinable static func returnInt(_ value: Int) {
        py_newint(py_retval(), py_i64(value))
    }
}

public extension Interpreter {
    /// Returns the module with the given name.
    /// - Parameter name: Module name for example: `__main__`
    /// - Returns: `PK.Module?`.
    @inlinable func module(_ name: String) -> PK.Module? {
        py_getmodule(name)
    }

    /// Returns the `__main__` module.
    ///
    /// Equivalent to `Interpreter.module("__main__")!`
    @inlinable static var main: PK.Module {
        Interpreter.shared.module("__main__")!
    }
}

@MainActor
public extension PK.Module {
    @inlinable func set(_ function: FunctionRegistration) {
        py_bind(self, function.signatureString, function.cFunction)
    }
}
