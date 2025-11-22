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

    /// Size of the value of `PyAPI.Reference`.
    static let elementSize = 24

    @inlinable
    static func `return`(_ value: PythonConvertible?) -> Bool {
        if let value {
            value.toPython(returnValue)
        } else {
            py_newnone(returnValue)
        }
        return true
    }

    @inlinable
    static func returnNone(_ block: () -> Void) -> Bool {
        block()
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func captureError(error: Error) -> Bool {
        if let error = error as? PythonError {
            return py_throw(error.type, error.description)
        }

        if let error = error as? StopIteration {
            let valueRef = error.value.toStack
            let objRef = try? PyType.StopIteration.new(valueRef.reference).toStack
            return py_raise(objRef?.reference)
        }

        return py_throw(.RuntimeError, error.localizedDescription)
    }
    
    @inlinable
    static func returnOrThrow(_ block: () throws -> Void) -> Bool {
        do {
            try block()
            return PyAPI.return(.none)
        } catch {
            return captureError(error: error)
        }
    }

    @inlinable
    static func returnOrThrow(_ block: () throws -> (any PythonConvertible)?) -> Bool {
        do {
            return try PyAPI.return(block())
        } catch {
            return captureError(error: error)
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
    @available(*, deprecated, message: "Use function.call() instead.")
    static func call(_ function: PyAPI.Reference?) throws -> PyAPI.Reference? {
        try Interpreter.printErrors {
            py_call(function, 0, nil)
        }
        return PyAPI.returnValue
    }

    static let pointerSize = Int32(MemoryLayout<UnsafeRawPointer>.size)
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

        return nil
    }

    /// Returns the module with the given name. If it can't find it, tries to import it.
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
    
    /// Calls the functon with the given arguments and returns the result.
    ///
    /// - Parameters:
    ///   - self: Optional self parameter.
    ///   - args: Array of arguments.
    /// - Returns: Return value of the function.
    @inlinable @discardableResult
    func call(self obj: PyAPI.Reference? = nil, _ args: [PyAPI.Reference?] = []) throws -> PyAPI.Reference? {
        guard py_callable(self) else {
            throw PythonError.AssertionError("Object is not callable")
        }
        
        try Interpreter.printErrors {
            py_push(self)

            if let obj {
                py_pushtmp().assign(obj)
            } else {
                py_pushnil()
            }

            var argc: UInt16 = 0
            for arg in args {
                if let arg {
                    py_pushtmp().assign(arg)
                } else {
                    py_pushnone()
                }
                argc += 1
            }
            return py_vectorcall(argc, 0)
        }

        return PyAPI.returnValue
    }

    /// Copies the given value into the reference memory.
    @inlinable func assign(_ newValue: PyAPI.Reference?) {
        guard let pointer = UnsafeRawPointer(newValue) else { return }
        UnsafeMutableRawPointer(self).copyMemory(from: pointer, byteCount: PyAPI.elementSize)
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
    
    @inlinable
    func attributeOrNil(_ name: String) -> PyAPI.Reference? {
        let hasError = Interpreter.ignoreErrors {
            py_getattr(self, py_name(name))
        }
        return !hasError ? nil : PyAPI.returnValue
    }
    
    @inlinable
    func castAttribute<Result: PythonConvertible>(_ name: String) throws -> Result {
        let ref = try attribute(name)?.toStack
        return try Result.cast(ref?.reference)
    }
    
    /// Returns a `ViewRepresentation` if the bounded object implements `ViewRepresentable`.
    @inlinable
    var view: ViewRepresentation? {
        let p0 = py_peek(0)
        
        if !py_getattr(self, py_name("__view__")) {
            py_clearexc(p0)
            return nil
        }
        
        return ViewRepresentation(PyAPI.returnValue)
    }
    
    /// Pushes `self` onto the Python stack and passes it as a temporary reference.
    /// - Parameter block: Closure receiving the temporary `PyAPI.Reference?`.
    /// - Throws: Errors thrown within the closure.
    @inlinable
    func temp(_ block: (PyAPI.Reference?) throws -> Void) throws {
        let tmp = py_pushtmp()
        defer { py_pop() }
        assign(tmp)
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
        PyAPI.Reference(
            UnsafeMutableRawPointer(self)
                .advanced(by: PyAPI.elementSize * index)
        )
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
            if let newValue {
                py_setslot(self, i, newValue)
            } else {
                py_setslot(self, i, py_None())
            }
        }
    }
    
    @inlinable
    func bind(_ signature: String, docstring: String? = nil, function: PyAPI.CFunction) {
        let temp = py_pushtmp()
        
        let doc = docstring?.withCString(strdup)
        let name = py_newfunction(temp, signature, function, doc, -1)

        let sigRet = signature.toStack
        py_setdict(temp, py_name("_signature"), sigRet.reference)
        
        var interface = "def \(signature):"
        
        if let docstring {
            interface += "\n    \"\"\"\(docstring)\"\"\""
        } else {
            interface += " ..."
        }
        let interfaceRet = interface.toStack
        py_setdict(temp, py_name("_interface"), interfaceRet.reference)
        
        py_setdict(self, name, temp)
        py_pop()
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
    
    static func argCountError(_ got: Int32, expected: Int) -> PythonError {
        .TypeError("expected \(expected) arguments, got \(got)")
    }

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
