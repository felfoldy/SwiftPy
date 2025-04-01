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

    static let r0 = py_getreg(0)

    @inlinable static func `return`(_ value: PythonConvertible?) -> Bool {
        py_retval().set(value)
        return true
    }
    
    @inlinable static func `throw`(_ error: PyType, _ message: String?) -> Bool {
        py_throw(error, message)
    }
    
    /// Calls a function with no arguments.
    /// - Parameters:
    ///   - function: Function to call
    /// - Returns: Return value from the function.
    @inlinable @discardableResult
    static func call(_ function: PyAPI.Reference?) throws -> PyAPI.Reference? {
        try Interpreter.printErrors {
            py_call(function, 0, nil)
        }
        return PyAPI.returnValue
    }
    
    /// Calls a function with a given argument.
    /// - Parameters:
    ///   - function: Function to call
    ///   - argument: Argument to pass.
    /// - Returns: Return value from the function.
    @inlinable @discardableResult
    static func call(_ function: PyAPI.Reference?, _ argument: PyAPI.Reference?) throws -> PyAPI.Reference? {
        try Interpreter.printErrors {
            py_call(function, 1, argument)
        }
        return PyAPI.returnValue
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

    @available(*, deprecated, message: "Use `make(_:base:module:bind:)` instead.")
    @inlinable static func make(_ name: String,
                                base: PyType = .object,
                                module: PyAPI.Reference = Interpreter.main,
                                dtor: py_Dtor,
                                bind: (PyType) -> Void) -> PyType {
        make(name, base: base, module: module, bind: bind)
    }
    
    @inlinable static func make(_ name: String,
                                base: PyType = .object,
                                module: PyAPI.Reference = Interpreter.main,
                                bind: (PyType) -> Void) -> PyType {
        let type = py_newtype(name, base, module) { userdata in
            // Dtor callback.
            guard let pointer = userdata?.load(as: UnsafeRawPointer?.self) else {
                return
            }

            // Tale retained value.
            let unmanaged = Unmanaged<AnyObject>.fromOpaque(pointer)
            let obj = unmanaged.takeRetainedValue()

            // Clear cache.
            if let bindable = (obj as? PythonBindable) {
                UnsafeRawPointer(bindable._pythonCache.reference)?.deallocate()
                bindable._pythonCache.reference = nil
            }
        }

        type.magic("__new__") { _, argv in
            let type = py_totype(argv)
            // For simplicity it always creates a dictionary.
            let ud = py_newobject(PyAPI.returnValue, type, -1, PyAPI.pointerSize)
            // Clear ud so if init fails it won't try to deinit a random address.
            ud?.storeBytes(of: nil, as: UnsafeRawPointer?.self)
            return true
        }

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
    static let main = PyAPI.Reference.modules.main
}

// MARK: - Modules

public extension PyAPI.Reference {
    @MainActor
    struct Modules {
        /// `__main__` module.
        let main = Interpreter.shared.module("__main__")!

        /// `builtins` module.
        let builtins = Interpreter.shared.module("builtins")!

        /// `intents` module.
        let intents = Interpreter.shared.module("intents")!
    }

    @MainActor static let modules = Modules()
}

// MARK: - Functions

public extension PyAPI.Reference {
    @MainActor
    struct Functions {
        let eval = PyAPI.Reference.modules.builtins["eval"]!
        let exec = PyAPI.Reference.modules.builtins["exec"]!
    }
    
    @MainActor static let functions = Functions()
}

// MARK: - Reference extensions

@MainActor
public extension PyAPI.Reference {
    @inlinable var userdata: UnsafeMutableRawPointer {
        py_touserdata(self)
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

    @inlinable func assign(_ newValue: PyAPI.Reference?) {
        py_assign(self, newValue)
    }

    @inlinable func setAttribute(_ name: String, _ value: PyAPI.Reference?) {
        try? Interpreter.printErrors {
            py_setattr(self, py_name(name), value)
        }
    }
    
    @inlinable func deleteAttribute(_ name: String) {
        try? Interpreter.printErrors {
            py_delattr(self, py_name(name))
        }
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
