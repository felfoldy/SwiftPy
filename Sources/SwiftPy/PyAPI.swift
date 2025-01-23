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

public enum PyType: py_Type {
    case int, str, bool, float
    
    public var rawValue: Int16 {
        switch self {
        case .int: py_Type(tp_int.rawValue)
        case .str: py_Type(tp_str.rawValue)
        case .bool: py_Type(tp_bool.rawValue)
        case .float: py_Type(tp_float.rawValue)
        }
    }
}

public extension PyAPI {
    /// Python function signature `(argc: Int32, argv: StackRef?) -> Bool`.
    typealias CFunction = py_CFunction

    typealias Reference = py_GlobalRef

    /// Sets the return value to None.
    @inlinable static func returnNone() {
        py_newnone(py_retval())
    }
    
    @inlinable static var returnValue: Reference {
        py_retval()
    }

    @inlinable static func returnInt(_ value: Int?) {
        returnNoneIfNil(value) { py_newint(py_retval(), py_i64($0)) }
    }

    @inlinable static func returnStr(_ value: String?) {
        returnNoneIfNil(value) { py_newstr(py_retval(), $0) }
    }

    @inlinable static func returnBool(_ value: Bool?) {
        returnNoneIfNil(value) { py_newbool(py_retval(), $0) }
    }

    @inlinable static func returnFloat(_ value: Double?) {
        returnNoneIfNil(value) { py_newfloat(py_retval(), $0) }
    }

    @inlinable static func returnNoneIfNil<T>(_ value: T?, callback: (T) -> Void) {
        if let value {
            callback(value)
        } else {
            py_newnone(py_retval())
        }
    }
}

public extension Interpreter {
    /// Returns the module with the given name.
    /// - Parameter name: Module name for example: `__main__`
    /// - Returns: `PK.Module?`.
    @inlinable func module(_ name: String) -> PyAPI.Reference? {
        py_getmodule(name)
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

    @inlinable func setAttribute(_ name: String, _ value: PythonConvertible?) {
        let r0 = py_getreg(0)
        value?.toPython(r0)
        py_setattr(self, py_name(name), r0)
    }

    @inlinable subscript(name: String) -> PyAPI.Reference? {
        py_getdict(self, py_name(name))
    }
    
    @inlinable func bind(_ function: FunctionRegistration) {
        py_bind(self, function.signature, function.cFunction)
    }

    @inlinable func isType(_ type: PyType) -> Bool {
        py_istype(self, type.rawValue)
    }
}

@MainActor public extension PyAPI.Reference? {
    @inlinable static func == <T: PythonConvertible>(lhs: PyAPI.Reference?, rhs: T?) -> Bool where T: Equatable {
        T(lhs) == rhs
    }
}
