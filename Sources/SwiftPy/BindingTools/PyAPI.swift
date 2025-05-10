//
//  PyAPI.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy
import Foundation

/// Namespace for pocketpy typealias/interfaces.
@MainActor
public enum PyAPI {}

public extension PyAPI {
    /// Python function signature `(argc: Int32, argv: StackRef?) -> Bool`.
    typealias CFunction = py_CFunction

    /// Just a type alias of an `OpaquePointer`.
    typealias Reference = py_Ref

    @inlinable
    static var returnValue: Reference {
        py_retval()
    }

    static let r0 = py_getreg(0)

    @inlinable
    static func `return`(_ value: PythonConvertible?) -> Bool {
        py_retval().set(value)
        return true
    }
    
    @inlinable
    static func returnNone(_ block: () -> Void) -> Bool {
        block()
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func returnOrThrow(_ block: () throws -> Void) -> Bool {
        do {
            try block()
            return PyAPI.return(.none)
        } catch let error as PythonError {
            return py_throw(error.type, error.description)
        } catch {
            return py_throw(.RuntimeError, error.localizedDescription)
        }
    }

    @inlinable
    static func returnOrThrow(_ block: () throws -> (any PythonConvertible)?) -> Bool {
        do {
            return try PyAPI.return(block())
        } catch let error as PythonError {
            return py_throw(error.type, error.description)
        } catch {
            return py_throw(.RuntimeError, error.localizedDescription)
        }
    }

    @inlinable
    static func `throw`(_ error: PyType, _ message: String?) -> Bool {
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
    
    @inlinable
    @discardableResult
    static func call(_ object: PyAPI.Reference, _ name: String) throws -> PyAPI.Reference? {
        let functionStack = try object.attribute(name)?.toStack
        if !py_callable(functionStack?.reference) {
            throw InterpreterError
                .notCallable(py_typeof(object).name)
        }
        try Interpreter.printErrors {
            py_call(functionStack?.reference, 0, nil)
        }
        return returnValue
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
    static let SyntaxError = PyType(tp_SyntaxError.rawValue)
    static let RecursionError = PyType(tp_RecursionError.rawValue)
    static let OSError = PyType(tp_OSError.rawValue)
    static let NotImplementedError = PyType(tp_NotImplementedError.rawValue)
    static let TypeError = PyType(tp_TypeError.rawValue)
    static let IndexError = PyType(tp_IndexError.rawValue)
    static let ValueError = PyType(tp_ValueError.rawValue)
    static let RuntimeError = PyType(tp_RuntimeError.rawValue)
    static let ZeroDivisionError = PyType(tp_ZeroDivisionError.rawValue)
    static let NameError = PyType(tp_NameError.rawValue)
    static let UnboundLocalError = PyType(tp_UnboundLocalError.rawValue)
    static let AttributeError = PyType(tp_AttributeError.rawValue)
    static let ImportError = PyType(tp_ImportError.rawValue)
    static let AssertionError = PyType(tp_AssertionError.rawValue)
    static let KeyError = PyType(tp_KeyError.rawValue)

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
    
    @available(*, deprecated, renamed: "staticFunction")
    @inlinable
    func classFunction(_ name: String, _ block: PyAPI.CFunction) {
        py_bindstaticmethod(self, name, block)
    }
    
    @inlinable
    func staticFunction(_ name: String, _ block: PyAPI.CFunction) {
        py_bindstaticmethod(self, name, block)
    }

    @inlinable
    var name: String {
        String(cString: py_tpname(self))
    }
    
    @inlinable
    var object: PyAPI.Reference? {
        py_tpobject(self)
    }
    
    @inlinable
    static func make(_ name: String,
                     base: PyType = .object,
                     module: PyAPI.Reference? = nil,
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

        bind(type)
        return type
    }
}

public extension Interpreter {
    @inlinable func module(_ name: String) -> PyAPI.Reference? {
        if let module = py_getmodule(name) {
            return module
        }

        let imported = try? Interpreter.printItemError(py_import(name))
        if imported == true {
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

@MainActor
public extension PyAPI.Reference {
    static let main = Interpreter.main

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
        let eval = py_getbuiltin(py_name("eval"))!
        let exec = py_getbuiltin(py_name("exec"))!
    }
    
    @MainActor static let functions = Functions()
}

// MARK: - Reference extensions

@MainActor
public extension PyAPI.Reference {
    @inlinable var userdata: UnsafeMutableRawPointer {
        py_touserdata(self)
    }
    
    @inlinable var isNil: Bool {
        py_istype(self, 0)
    }
    
    @inlinable var isNone: Bool {
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
    
    /// Retrieves the attribute with the given name and passes it as a temporary reference.
    /// - Parameters:
    ///   - name: The attribute name.
    ///   - block: Closure receiving the temporary python object.
    /// - Throws: Errors from the Python interpreter.
    @inlinable
    func attribute(_ name: String, block: (PyAPI.Reference?) throws -> Void) throws {
        try Interpreter.printErrors {
            py_getattr(self, py_name(name))
        }
        try PyAPI.returnValue.temp { tmp in
            try block(tmp)
        }
    }
    
    @inlinable
    func attribute(_ name: String) throws -> PyAPI.Reference? {
        try Interpreter.printErrors {
            py_getattr(self, py_name(name))
        }
        return PyAPI.returnValue
    }
    
    /// Pushes `self` onto the Python stack and passes it as a temporary reference.
    /// - Parameter block: Closure receiving the temporary `PyAPI.Reference?`.
    /// - Throws: Errors thrown within the closure.
    @inlinable
    func temp(_ block: (PyAPI.Reference?) throws -> Void) throws {
        let tmp = py_pushtmp()
        defer { py_pop() }
        py_assign(tmp, self)
        try block(tmp)
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
    
    /// Moves the reference to a register at the specific index.
    /// - Parameter index: index
    /// - Returns: Reference to the register.
    @inlinable func toRegister(_ index: Int32) -> PyAPI.Reference? {
        let register = py_getreg(index)
        register?.assign(self)
        return register
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
    
    @inlinable
    subscript(index: Int) -> PyAPI.Reference? {
        let argument = Int(bitPattern: self) + (index << 4)
        return PyAPI.Reference(bitPattern: argument)
    }
    
    @inlinable
    subscript(slot i: Int32) -> PyAPI.Reference? {
        get {
            guard let result = py_getslot(self, i),
                  !result.isNil else {
                return nil
            }
            return result
        }
        nonmutating set {
            py_setslot(self, i, newValue)
        }
    }
    
    @inlinable
    func bind(_ signature: String, function: PyAPI.CFunction) {
        py_bind(self, signature, function)
    }

    @inlinable func isType<T: PythonConvertible>(_ type: T.Type) -> Bool {
        py_istype(self, T.pyType)
    }
    
    @inlinable func isInstance(of type: PyType) -> Bool {
        py_isinstance(self, type)
    }
    
    @inlinable
    func canCast(to type: PyType) -> Bool {
        if py_isinstance(self, type) {
            return true
        }
        if type == .float, canCast(to: .int) {
            return true
        }
        return false
    }
}

@MainActor public extension PyAPI.Reference? {
    @inlinable static func == <T: PythonConvertible>(lhs: PyAPI.Reference?, rhs: T?) -> Bool where T: Equatable {
        T(lhs) == rhs
    }
}

public enum PythonError: LocalizedError {
    case SyntaxError(String)
    case RecursionError(String)
    case OSError(String)
    case NotImplementedError(String)
    case TypeError(String)
    case IndexError(String)
    case ValueError(String)
    case RuntimeError(String)
    case ZeroDivisionError(String)
    case NameError(String)
    case UnboundLocalError(String)
    case AttributeError(String)
    case ImportError(String)
    case AssertionError(String)
    case KeyError(String)

    public var description: String? {
        switch self {
        case let .SyntaxError(msg): msg
        case let .RecursionError(msg): msg
        case let .OSError(msg): msg
        case let .NotImplementedError(msg): msg
        case let .TypeError(msg): msg
        case let .IndexError(msg): msg
        case let .ValueError(msg): msg
        case let .RuntimeError(msg): msg
        case let .ZeroDivisionError(msg): msg
        case let .NameError(msg): msg
        case let .UnboundLocalError(msg): msg
        case let .AttributeError(msg): msg
        case let .ImportError(msg): msg
        case let .AssertionError(msg): msg
        case let .KeyError(msg): msg
        }
    }
    
    @MainActor
    @inlinable
    public var type: PyType {
        switch self {
        case .SyntaxError: .SyntaxError
        case .RecursionError: .RecursionError
        case .OSError: .OSError
        case .NotImplementedError: .NotImplementedError
        case .TypeError: .TypeError
        case .IndexError: .IndexError
        case .ValueError: .ValueError
        case .RuntimeError: .RuntimeError
        case .ZeroDivisionError: .ZeroDivisionError
        case .NameError: .NameError
        case .UnboundLocalError: .UnboundLocalError
        case .AttributeError: .AttributeError
        case .ImportError: .ImportError
        case .AssertionError: .AssertionError
        case .KeyError: .KeyError
        }
    }
}
