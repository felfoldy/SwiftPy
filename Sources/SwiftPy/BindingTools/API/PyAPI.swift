//
//  PyAPI.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy
import Foundation

@MainActor
public let py = PyAPI()

/// Namespace for pocketpy typealias/interfaces.
@MainActor
public struct PyAPI {
    /// Python function signature `(argc: Int32, argv: StackRef?) -> Bool`.
    public typealias CFunction = py_CFunction

    /// Just a type alias of an `OpaquePointer`.
    public typealias Reference = py_Ref

    /// VM callbacks.
    public typealias Callbacks = py_Callbacks
    
    public typealias pyCompileMode = py_CompileMode
    
    public let dict = Dict()
    public let list = List()
    public let tuple = Tuple()

    @inlinable
    public var callbacks: Callbacks {
        get { py_callbacks().pointee }
        nonmutating set { py_callbacks().pointee = newValue }
    }

    @inlinable
    init() {
        py_initialize()

        // Remove exit:
        let builtins = py_getmodule("builtins")
        py_deldict(builtins, py_name("exit"))
    }
    
    @inlinable
    public func getmodule(_ name: String) -> PyAPI.Reference? {
        py_getmodule(name)
    }
    
    @inlinable
    public func newmodule(_ path: String) -> PyAPI.Reference {
        py_newmodule(path)
    }
    
    @inlinable
    public func getdict(_ self: PyAPI.Reference, name: String) -> PyAPI.Reference? {
        py_getdict(self, py_name(name))
    }
    
    @inlinable
    public func setdict(_ self: PyAPI.Reference, name: String, value: PyAPI.Reference?) {
        py_setdict(self, py_name(name), value ?? py_None())
    }

    // TODO: Better error handling
    @inlinable
    public func repr(_ value: PyAPI.Reference?) -> Bool {
        py_repr(value)
    }

    // TODO: Better error handling
    @inlinable
    public func getattr(_ self: PyAPI.Reference, name: String) -> Bool {
        py_getattr(self, py_name(name))
    }
    
    // TODO: Better error handling
    @inlinable
    public func setattr(_ self: PyAPI.Reference, name: String, value: PyAPI.Reference?) -> Bool {
        py_setattr(self, py_name(name), value ?? py_None())
    }

    // TODO: Better error handling
    @inlinable
    public func iter(_ self: PyAPI.Reference?) -> Bool {
        py_iter(self)
    }

    // TODO: Better error handling
    // (1: success, 0: StopIteration, -1: error)
    @inlinable
    public func next(_ self: PyAPI.Reference?) -> Int32 {
        py_next(self)
    }

    // TODO: Better error handling
    @inlinable
    public func compile(source: String, filename: String, mode: CompileMode) -> Bool {
        py_compile(source, filename, mode.pyMode, false)
    }
    
    // TODO: Better error handling
    @inlinable
    public func exec(source: String, filename: String, mode: CompileMode, module: PyAPI.Reference?) -> Bool {
        py_exec(source, filename, mode.pyMode, module)
    }

    // TODO: Better error handling
    // Call a callable object via pocketpy’s calling convention. You need to prepare the stack using the following format: callable, self/nil, arg1, arg2, ..., k1, v1, k2, v2, .... argc is the number of positional arguments excluding self. kwargc is the number of keyword arguments. The result will be set to py.returnValue. The stack size will be reduced by 2 + argc + kwargc * 2
    @inlinable
    public func vectorcall(argc: UInt16, kwargc: UInt16) -> Bool {
        py_vectorcall(argc, kwargc)
    }

    @inlinable
    public func callable(_ self: PyAPI.Reference) -> Bool {
        py_callable(self)
    }

    @discardableResult
    @inlinable
    public func newobject(_ out: PyAPI.Reference, type: PyType, slots: Int32) -> UnsafeMutablePointer<UnsafeRawPointer?> {
        let ud = py_newobject(
            out,
            type,
            slots,
            Int32(MemoryLayout<UnsafeRawPointer>.size)
        )
        .assumingMemoryBound(to: UnsafeRawPointer?.self)
        ud.initialize(to: nil)
        return ud
    }

    // MARK: - Stack accessors
    
    @inlinable
    public func push(_ ref: PyAPI.Reference) {
        py_push(ref)
    }

    @inlinable
    public func pushnil() {
        py_pushnil()
    }
    
    /// Get a temporary variable from the stack.
    @inlinable
    public func pushtmp() -> PyAPI.Reference {
        py_pushtmp()
    }
    
    @inlinable
    public func pushnone() {
        py_pushnone()
    }

    @inlinable
    public func pop() {
        py_pop()
    }

    @inlinable
    public func peek() -> PyAPI.Reference {
        py_peek(0)
    }

    @inlinable
    public func printexc() {
        py_printexc()
    }
    
    @inlinable
    public func clearexc(_ unwindingPoint: PyAPI.Reference) {
        py_clearexc(unwindingPoint)
    }
}

// MARK: PyType extensions.

public extension PyAPI {
    /// Get the type of the object.
    @inlinable
    func typeof(_ self: PyAPI.Reference?) -> PyType {
        py_typeof(self ?? py_None())
    }

    /// Convert a type object in python to PyType.
    @inlinable
    func totype(_ typeObject: PyAPI.Reference?) -> PyType {
        py_totype(typeObject)
    }
    
    @inlinable
    func istype(_ self: PyAPI.Reference?, type: PyType) -> Bool {
        py_istype(self, type)
    }
    
    @inlinable
    func isinstance(_ obj: PyAPI.Reference?, type: PyType) -> Bool {
        py_isinstance(obj, type)
    }

    @inlinable
    func newtype(
        name: String,
        base: PyType,
        module: PyAPI.Reference?,
        dtor: @convention(c) (UnsafeMutableRawPointer?) -> Void
    ) -> PyType {
        py_newtype(name, base, module, dtor)
    }
    
    @inlinable
    func tpname(_ type: PyType) -> String {
        String(cString: py_tpname(type))
    }
    
    @inlinable
    func tpobject(_ type: PyType) -> PyAPI.Reference? {
        py_tpobject(type)
    }
    
    @inlinable
    func bindproperty(type: PyType, name: String, getter: PyAPI.CFunction, setter: PyAPI.CFunction?) {
        py_bindproperty(type, name, getter, setter)
    }
    
    // TODO: Use lower level implementation with signature.
    @inlinable
    func bindmagic(type: PyType, name: String, function: PyAPI.CFunction) {
        py_bindmagic(type, py_name(name), function)
    }
    
    // TODO: Use lower level implementation with signature.
    @inlinable
    func bindstaticmethod(type: PyType, name: String, function: PyAPI.CFunction) {
        py_bindstaticmethod(type, name, function)
    }
}

// MARK: - Native type conversions

public extension PyAPI {
    struct Dict {
        // TODO: Better error handling
        // (1: found, 0: not found, -1: error)
        @inlinable
        public func getitem(_ self: PyAPI.Reference, key: PyAPI.Reference?) -> Int32 {
            py_dict_getitem(self, key)
        }
        
        // TODO: Better error handling
        @inlinable
        public func setitem(_ self: PyAPI.Reference, key: PyAPI.Reference?, value: PyAPI.Reference?) -> Bool {
            py_dict_setitem(self, key, value)
        }
    }
    
    struct List {
        @inlinable
        public func append(_ self: PyAPI.Reference, value: PyAPI.Reference?) {
            py_list_append(self, value)
        }
    }
    
    struct Tuple {
        @inlinable
        public func getitem(_ self: PyAPI.Reference?, i: Int32) -> PyAPI.Reference? {
            py_tuple_getitem(self, i)
        }
    }
    
    @inlinable
    func newbool(_ out: PyAPI.Reference, value: Bool) {
        py_newbool(out, value)
    }
    
    @inlinable
    func tobool(_ self: PyAPI.Reference) -> Bool {
        py_tobool(self)
    }
    
    @inlinable
    func newint(_ out: PyAPI.Reference, value: Int) {
        py_newint(out, py_i64(value))
    }
    
    @inlinable
    func toint(_ self: PyAPI.Reference) -> Int {
        Int(py_toint(self))
    }
    
    @inlinable
    func newstr(_ out: PyAPI.Reference, value: String) {
        py_newstr(out, value)
    }
    
    @inlinable
    func tostr(_ self: PyAPI.Reference) -> String {
        String(cString: py_tostr(self))
    }
    
    @inlinable
    func newfloat(_ out: PyAPI.Reference, value: Double) {
        py_newfloat(out, value)
    }
    
    @inlinable
    func castfloat(_ self: PyAPI.Reference) -> Double {
        switch self.pointee.type {
        case .int: Double(self.pointee._i64)
        case .float: self.pointee._f64
        default: 0
        }
    }

    @inlinable
    func newbytes(_ out: PyAPI.Reference, n: Int) -> UnsafeMutableRawBufferPointer {
        let pointer = py_newbytes(out, Int32(n))
        return UnsafeMutableRawBufferPointer(start: pointer, count: n)
    }
    
    @inlinable
    func tobytes(_ self: PyAPI.Reference) -> Data {
        var size: Int32 = 0
        guard let bytes = py_tobytes(self, &size) else {
            return Data()
        }
        return Data(bytes: bytes, count: Int(size))
    }
    
    @inlinable
    func newnone(_ out: PyAPI.Reference) {
        py_newnone(out)
    }
    
    @inlinable
    func newlist(_ out: PyAPI.Reference) {
        py_newlist(out)
    }
    
    @inlinable
    func newdict(_ out: PyAPI.Reference) {
        py_newdict(out)
    }
}

public extension PyAPI {
    @inlinable
    static var returnValue: Reference {
        py_retval()
    }

    /// Size of the value of `PyAPI.Reference`.
    static let elementSize = 24

    @inlinable
    static func `return`(_ value: Any?) -> Bool {
        guard let value else {
            py_newnone(returnValue)
            return true
        }
        if let pythonValue = value as? PythonConvertible {
            pythonValue.toPython(returnValue)
        } else {
            SwiftObject(value).toPython(returnValue)
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
            let stopIterationType = PyObject(.StopIteration)
            let stopIteration: PyAPI.Reference? = try? stopIterationType(error.value)

            return py_raise(stopIteration)
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

// MARK: - PyType

/// `Int16`
public typealias PyType = py_Type

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
        guard py.callable(self) else {
            throw PythonError.AssertionError("Object is not callable")
        }
        
        try Interpreter.printErrors {
            py.push(self)

            if let obj {
                py.pushtmp().assign(obj)
            } else {
                py.pushnil()
            }

            var argc: UInt16 = 0
            for arg in args {
                if let arg {
                    py.pushtmp().assign(arg)
                } else {
                    py.pushnone()
                }
                argc += 1
            }
            return py.vectorcall(argc: argc, kwargc: 0)
        }

        return PyAPI.returnValue
    }

    /// Copies the given value into the reference memory.
    @inlinable func assign(_ newValue: PyAPI.Reference?) {
        guard let newValue else { return }
        pointee = newValue.pointee
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
            py.getattr(self, name: name)
        }
        return PyAPI.returnValue
    }
    
    @inlinable
    func attributeOrNil(_ name: String) -> PyAPI.Reference? {
        let hasError = Interpreter.ignoreErrors {
            py.getattr(self, name: name)
        }
        return !hasError ? nil : PyAPI.returnValue
    }
    
    @inlinable
    func castAttribute<Result: PythonConvertible>(_ name: String) throws -> Result {
        let ref = try attribute(name)?.retained
        return try Result.cast(ref?.reference)
    }
    
    /// Returns a `ViewRepresentation` if the bounded object implements `ViewRepresentable`.
    @inlinable
    var view: ViewRepresentation? {
        let p0 = py_peek(0)
        
        if !py.getattr(self, name: "__view__") {
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
            py.setattr(self, name: name, value: value)
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
    
    @inlinable func emplace(_ name: String) -> PyAPI.Reference {
        py_emplacedict(self, py_name(name))
    }

    @inlinable
    subscript(name: String) -> PyAPI.Reference? {
        py.getdict(self, name: name)
    }
    
    @inlinable
    subscript(index: Int) -> PyAPI.Reference? {
        advanced(by: index)
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
        let temp = py.pushtmp()
        
        let doc = docstring?.withCString(strdup)
        let name = py_newfunction(temp, signature, function, doc, -1)

        let sigRet = TempPyObject(signature)
        py.setdict(temp, name: "_signature", value: sigRet?.reference)

        var interface = "def \(signature):"
        if let docstring {
            interface += "\n    \"\"\"\(docstring)\"\"\""
        } else {
            interface += " ..."
        }
        let interfaceRet = interface.retained
        py.setdict(
            temp,
            name: "_interface",
            value: interfaceRet.reference
        )

        py_setdict(self, name, temp)
        py.pop()
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
        switch type {
        case .float:
            if canCast(to: .int) {
                return true
            }
        case .str:
            if canCast(to: Path.pyType) {
                return true
            }
        default: break
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
