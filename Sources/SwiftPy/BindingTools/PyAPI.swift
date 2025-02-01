//
//  PyAPI.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy

/// Namespace for pocketpy typealias/interfaces.
@MainActor
public enum PyAPI {}

public extension PyAPI {
    /// Python function signature `(argc: Int32, argv: StackRef?) -> Bool`.
    typealias CFunction = py_CFunction

    /// Just a type alias of an `OpaquePointer`.
    typealias Reference = py_Ref

    @inlinable static var returnValue: Reference {
        py_retval()
    }
}

public extension Interpreter {
    /// Returns the module with the given name. If it can't find it, tries to import it.
    /// - Parameter name: Module name for example: `__main__`
    /// - Returns: Module reference.
    @inlinable func module(_ name: String) -> PyAPI.Reference? {
        if let module = py_getmodule(name) {
            return module
        }
        if py_import(name) == 1 {
            return PyAPI.returnValue
        }
        return nil
    }

    /// Returns the `__main__` module.
    ///
    /// Equivalent to `Interpreter.module("__main__")!`
    @inlinable static var main: PyAPI.Reference {
        Interpreter.shared.module("__main__")!
    }
}

// MARK: - Reference extensions

@MainActor
public extension PyAPI.Reference {
    @inlinable func setNone() {
        py_newnone(self)
    }

    @inlinable func isNone() -> Bool {
        py_istype(self, py_Type(tp_NoneType.rawValue))
    }

    @inlinable func set(_ value: PythonConvertible?) {
        if let value {
            value.toPython(self)
        } else {
            py_newnone(self)
        }
    }
    
    @inlinable func setAttribute(_ name: String, _ value: PyAPI.Reference?) {
        py_setattr(self, py_name(name), value)
    }

    @inlinable subscript(name: String) -> PyAPI.Reference? {
        py_getdict(self, py_name(name))
    }
    
    @inlinable func bind(_ function: FunctionRegistration) {
        py_bind(self, function.signature, function.cFunction)
    }

    @inlinable func isType<T: PythonConvertible>(_ type: T.Type) -> Bool {
        py_istype(self, T.pyType)
    }
}

@MainActor public extension PyAPI.Reference? {
    @inlinable static func == <T: PythonConvertible>(lhs: PyAPI.Reference?, rhs: T?) -> Bool where T: Equatable {
        T(lhs) == rhs
    }
}
