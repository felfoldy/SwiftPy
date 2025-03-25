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

    @inlinable static func `return`(_ value: PythonConvertible?) -> Bool {
        py_retval().set(value)
        return true
    }
    
    @inlinable static func `throw`(_ error: PyType, _ message: String?) -> Bool {
        py_throw(error, message)
    }

    static let pointerSize = Int32(MemoryLayout<UnsafeRawPointer>.size)
}

public typealias PyType = py_Type

@MainActor
public extension PyType {
    static let None = PyType(tp_NoneType.rawValue)
    static let bool = PyType(tp_bool.rawValue)
    static let int = PyType(tp_int.rawValue)
    static let str = PyType(tp_str.rawValue)
    static let float = PyType(tp_float.rawValue)
    static let list = PyType(tp_list.rawValue)
    static let object = PyType(tp_object.rawValue)
    static let dict = PyType(tp_dict.rawValue)
    static let function = PyType(tp_function.rawValue)
    
    // Errors:
    static let TypeError = PyType(tp_TypeError.rawValue)

    @inlinable
    func magic(_ name: String, function: PyAPI.CFunction) {
        py_newnativefunc(py_tpgetmagic(self, py_name(name)), function)
    }
    
    @inlinable
    func property(_ name: String, getter: PyAPI.CFunction, setter: PyAPI.CFunction? = nil) {
        py_bindproperty(self, name, getter, setter)
    }
    
    @inlinable
    func function(_ signature: String, block: PyAPI.CFunction) {
        py_bind(py_tpobject(self), signature, block)
    }

    @inlinable var name: String {
        String(cString: py_tpname(self))
    }
    
    @inlinable var object: PyAPI.Reference? {
        py_tpobject(self)
    }

    @inlinable static func make(_ name: String,
                                base: PyType = .object,
                                module: PyAPI.Reference = Interpreter.main,
                                dtor: py_Dtor,
                                bind: (PyType) -> Void) -> PyType {
        let type = py_newtype(name, base, module, dtor)
        bind(type)
        return type
    }
}

public extension Interpreter {
    @inlinable func module(_ name: String) -> PyAPI.Reference? {
        if let module = py_getmodule(name) {
            return module
        }
        if py_import(name) == 1 {
            return PyAPI.returnValue
        }
        return py_newmodule(name)
    }

    /// Returns the module with the given name. If it can't find it, tries to import it. If can't import it it will created.
    /// - Parameter name: Module name for example: `__main__`
    /// - Returns: Module reference.
    @inlinable static func module(_ name: String) -> PyAPI.Reference? {
        shared.module(name)
    }
    
    /// `__main__` module.
    static let main = Interpreter.shared.module("__main__")!

    /// `builtins` module
    static let builtins = Interpreter.shared.module("builtins")!
    
    /// `intents` module
    @available(macOS 13.0, iOS 16.0, *)
    static let intents = Interpreter.shared.module("intents")!

    static let eval = builtins["eval"]!
    static let exec = builtins["exec"]!
}

// MARK: - Reference extensions

@MainActor
public extension PyAPI.Reference {
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
    
    @inlinable func deleteAttribute(_ name: String) {
        py_delattr(self, py_name(name))
    }
    
    /// Adds the types to the module.
    /// - Parameter types: types to add.
    @inlinable func insertTypes(_ types: PyType...) {
        for type in types {
            py_setattr(self, py_name(type.name), type.object)
        }
    }
    
    @inlinable func emplace(_ name: String) -> PyAPI.Reference {
        py_emplacedict(self, py_name(name))
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
