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

public typealias PyType = py_Type

public extension PyType {
    static let None = PyType(tp_NoneType.rawValue)
    static let bool = PyType(tp_bool.rawValue)
    static let int = PyType(tp_int.rawValue)
    static let str = PyType(tp_str.rawValue)
    static let float = PyType(tp_float.rawValue)
    static let list = PyType(tp_list.rawValue)
    static let object = PyType(tp_object.rawValue)
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
        py_istype(self, PyType.None)
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
    
    @inlinable subscript(index: Int) -> PyAPI.Reference? {
        let argument = Int(bitPattern: self) + (index << 4)
        return PyAPI.Reference(bitPattern: argument)
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
