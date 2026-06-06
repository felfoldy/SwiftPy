//
//  PyAPI.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy
import Foundation
import SwiftUI

@MainActor
public let py = PyAPI()

public typealias PyRef = PyAPI.Reference
public typealias PyValue = PyAPI.Value


public protocol PyReferencing {
    var reference: PyRef { get }
}

extension PyRef: @MainActor PyReferencing {
    @inlinable public var reference: PyRef { self }
}

/// Namespace for pocketpy typealias/interfaces.
@MainActor
public struct PyAPI {
    /// Python function signature `(argc: Int32, argv: StackRef?) -> Bool`.
    public typealias CFunction = @convention(c) (Int32, PyRef?) -> Bool

    public typealias Reference = UnsafeMutablePointer<Value>

    public typealias Value = py_TValue

    /// VM callbacks.
    public typealias Callbacks = py_Callbacks
    
    public typealias pyCompileMode = py_CompileMode

    public let version = PK_VERSION

    public let dict = Dict()
    public let list = List()
    public let tuple = Tuple()
    
    public let objectCache: PyRef
    
    @inlinable
    public var callbacks: Callbacks {
        get { py_callbacks().pointee }
        nonmutating set { py_callbacks().pointee = newValue }
    }
    
    @inlinable
    public var retval: PyRef {
        py_retval()
    }

    @inlinable
    init() {
        py_initialize()

        // Remove exit:
        let builtins = py_getmodule("builtins")
        py_deldict(builtins, py_name("exit"))

        // Reserve register 0 as object cache list.
        let r0 = py_getreg(0)!
        py_newlist(r0)
        objectCache = r0
    }

    func None() -> PyRef {
        py_None()
    }

    @inlinable
    public func getmodule(_ name: String) -> PyRef? {
        py_getmodule(name)
    }
    
    @inlinable
    public func newmodule(_ path: String) -> PyRef {
        py_newmodule(path)
    }
    
    @inlinable
    public func `import`(_ name: String) throws -> PyRef? {
        let result = py_import(name)
        let retval = try PyAPI.convertRetval {
            result != -1
        }
        return result == 1 ? retval : nil
    }
    
    @inlinable
    public func getdict(_ self: PyRef, name: String) -> PyRef? {
        py_getdict(self, py_name(name))
    }
    
    @inlinable
    public func setdict(_ self: PyRef?, name: String, value: PyRef?) {
        py_setdict(self, py_name(name), value ?? py_None())
    }

    @discardableResult
    @inlinable
    public static func convertRetval(
        silenceErrors: Bool = false,
        _ call: () -> Bool
    ) throws(PythonError) -> PyRef {
        let p0 = py.peek()
        if call() {
            return py.retval
        }

        let ok = py_matchexc(.BaseException)
        precondition(ok)
        if !silenceErrors && !Interpreter.silenceErrors {
            Interpreter.output.stderr(String(cString: py_formatexc()))
        }
        py.clearexc(p0)

        throw try PythonError.cast(py.retval)
    }

    @discardableResult
    @inlinable
    public static func convertRetval(
        _ value: PyRef?,
        _ call: (PyRef) -> Bool
    ) throws(PythonError) -> PyRef {
        let tmp = py.pushtmp()
        tmp.assign(value)
        defer { py.pop() }
        return try convertRetval {
            call(tmp)
        }
    }

    @inlinable
    public func repr(_ value: PyRef?) throws(PythonError) -> String {
        let result = try PyAPI.convertRetval(value) { tmp in
            py_repr(tmp)
        }

        return try String.cast(result)
    }

    @inlinable
    public func getattr(_ self: PyRef, name: String) throws(PythonError) -> PyRef {
        try PyAPI.convertRetval(self) { tmp in
            py_getattr(tmp, py_name(name))
        }
    }

    @inlinable
    public func setattr(_ self: PyRef, name: String, value: PyRef?) throws(PythonError) {
        try PyAPI.convertRetval(self) { tmp in
            py_setattr(tmp, py_name(name), value ?? py_None())
        }
    }

    @inlinable
    public func iter(_ self: PyRef?) throws(PythonError) -> PyRef {
        try PyAPI.convertRetval(self) { tmp in
            py_iter(tmp)
        }
    }
    
    @inlinable
    public func next(_ val: PyRef) throws(PythonError) -> PyRef {
        let result = try PyAPI.convertRetval(val) { val in
            let result = py_next(val)
            return result != -1
        }
        if let stopIteration = PythonError(result) {
            throw stopIteration
        }
        return result
    }

    @inlinable
    public func compile(source: String, filename: String, mode: CompileMode) throws(PythonError) -> PyRef {
        try PyAPI.convertRetval {
            py_compile(source, filename, mode.pyMode, false)
        }
    }
    
    @inlinable
    public func exec(source: String, filename: String, mode: CompileMode, module: PyRef?) throws(PythonError) -> PyRef {
        try PyAPI.convertRetval {
            py_exec(source, filename, mode.pyMode, module)
        }
    }

    @discardableResult
    @inlinable
    public func call(_ function: PyRef, args: PythonConvertible?...) throws(PythonError) -> PyRef {
        try PyAPI.convertRetval(function) { function in
            py.push(function)
            py.pushnil()

            for arg in args {
                if let arg {
                    arg.toPython(py.pushtmp())
                } else {
                    py.pushnone()
                }
            }

            return py_vectorcall(UInt16(args.count), 0)
        }
    }

    @inlinable
    public func callable(_ self: PyRef) -> Bool {
        py_callable(self)
    }

    @discardableResult
    @inlinable
    public func newobject(_ out: PyRef, type: PyType, slots: Int32) -> UnsafeMutablePointer<UnsafeRawPointer?> {
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

    @inlinable
    public func newobject<T: PythonConvertible>(
        _ value: T,
        type: PyType,
        out: PyRef,
        slots: Int32
    ) {
        let ud = py_newobject(out, type, slots, Int32(MemoryLayout<T>.size))
            .assumingMemoryBound(to: T.self)
        ud.initialize(to: value)
    }

    // MARK: - Stack accessors
    
    @inlinable
    public func push(_ ref: PyRef?) {
        py_push(ref)
    }

    @inlinable
    public func pushnil() {
        py_pushnil()
    }
    
    /// Get a temporary variable from the stack.
    @inlinable
    public func pushtmp() -> PyRef {
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
    public func peek() -> PyRef {
        py_peek(0)
    }

    @inlinable
    public func printexc() {
        py_printexc()
    }
    
    @inlinable
    public func clearexc(_ unwindingPoint: PyRef) {
        py_clearexc(unwindingPoint)
    }
}

// MARK: PyType extensions.

public extension PyAPI {
    /// Get the type of the object.
    @inlinable
    func typeof(_ self: PyRef?) -> PyType {
        py_typeof(self ?? py_None())
    }
    
    /// Convert a type object in python to PyType.
    @inlinable
    func totype(_ typeObject: PyRef?) -> PyType {
        py_totype(typeObject)
    }
    
    @inlinable
    func istype(_ self: PyRef?, type: PyType) -> Bool {
        py_istype(self, type)
    }
    
    @inlinable
    func isinstance(_ obj: PyRef?, type: PyType) -> Bool {
        py_isinstance(obj, type)
    }
    
    @inlinable
    func newtype(
        name: String,
        base: PyType,
        module: PyRef?,
        dtor: @convention(c) (UnsafeMutableRawPointer?) -> Void
    ) -> PyType {
        py_newtype(name, base, module, dtor)
    }
    
    @inlinable
    func tpname(_ type: PyType) -> String {
        String(cString: py_tpname(type))
    }
    
    @inlinable
    func tpobject(_ type: PyType) -> PyRef? {
        py_tpobject(type)
    }
    
    @inlinable
    func bindproperty(type: PyType, name: String, getter: PyAPI.CFunction, setter: PyAPI.CFunction?) {
        py_bindproperty(type, name, getter, setter)
    }
    
    @inlinable
    func newnativefunc(_ function: PyAPI.CFunction) -> PyRef {
        let out = PyRef.allocate(capacity: 1)
        out.initialize(to: py_TValue())
        py_newnativefunc(out, function)
        return out
    }

    @discardableResult
    @inlinable
    func newfunction(_ out: PyRef, signature: String, docstring: String?, function: PyAPI.CFunction) -> String {
        let docstring = docstring?.withCString(strdup)
        let name = py_newfunction(out, signature, function, docstring, -1)
        return String(cString: py_name2str(name))
    }
}

// MARK: - Native type conversions

public extension PyAPI {
    @MainActor
    struct Dict {
        @inlinable
        public func len(_ self: PyRef?) -> Int32 {
            py_dict_len(self)
        }

        @inlinable
        public func getitem(_ self: PyRef, key: PyRef?) throws -> PyRef? {
            let result = py_dict_getitem(self, key)
            let retval = try PyAPI.convertRetval {
                result != -1
            }
            return result == 1 ? retval : nil
        }
        
        @inlinable
        public func getitem(_ self: PyRef?, i: Int64) throws -> PyRef? {
            let result = py_dict_getitem_by_int(self, i)
            let retval = try PyAPI.convertRetval {
                result != -1
            }
            return result == 1 ? retval : nil
        }

        @inlinable
        public func setitem(_ self: PyRef, key: PyRef?, value: PyRef?) throws(PythonError) -> PyRef {
            try PyAPI.convertRetval(self) { temp in
                py_dict_setitem(self, key, value)
            }
        }
    }
    
    struct List {
        @inlinable
        public func append(_ self: PyRef, value: PyRef?) {
            py_list_append(self, value)
        }

        @inlinable
        public func setitem(_ self: PyRef, i: Int32, value: PyRef?) {
            py_list_setitem(self, i, value)
        }
        
        @inlinable
        public func getitem(_ self: PyRef, i: Int32) -> PyRef {
            py_list_getitem(self, i)
        }
        
        @inlinable
        public func len(_ self: PyRef) -> Int32 {
            py_list_len(self)
        }
    }
    
    struct Tuple {
        @inlinable
        public func getitem(_ self: PyRef?, i: Int32) -> PyRef? {
            py_tuple_getitem(self, i)
        }

        @inlinable
        public func len(_ self: PyRef?) -> Int32 {
            py_tuple_len(self)
        }
    }
    
    @inlinable
    func newbool(_ out: PyRef, value: Bool) {
        py_newbool(out, value)
    }
    
    @inlinable
    func tobool(_ self: PyRef) -> Bool {
        py_tobool(self)
    }
    
    @inlinable
    func newint(_ out: PyRef, value: Int) {
        py_newint(out, py_i64(value))
    }
    
    @inlinable
    func toint(_ self: PyRef) -> Int {
        Int(py_toint(self))
    }
    
    @inlinable
    func newstr(_ out: PyRef, value: String) {
        py_newstr(out, value)
    }
    
    @inlinable
    func tostr(_ self: PyRef) -> String {
        String(cString: py_tostr(self))
    }
    
    @inlinable
    func newfloat(_ out: PyRef, value: Double) {
        py_newfloat(out, value)
    }
    
    @inlinable
    func castfloat(_ self: PyRef) -> Double {
        switch self.pointee.type {
        case .int: Double(self.pointee._i64)
        case .float: self.pointee._f64
        default: 0
        }
    }

    @inlinable
    func newbytes(_ out: PyRef, n: Int) -> UnsafeMutableRawBufferPointer {
        let pointer = py_newbytes(out, Int32(n))
        return UnsafeMutableRawBufferPointer(start: pointer, count: n)
    }
    
    @inlinable
    func tobytes(_ self: PyRef) -> Data {
        var size: Int32 = 0
        guard let bytes = py_tobytes(self, &size) else {
            return Data()
        }
        return Data(bytes: bytes, count: Int(size))
    }
    
    @inlinable
    func newnone(_ out: PyRef) {
        py_newnone(out)
    }
    
    @inlinable
    func newlist(_ out: PyRef) {
        py_newlist(out)
    }
    
    @inlinable
    func newdict(_ out: PyRef) {
        py_newdict(out)
    }
}

public extension PyAPI {
    @inlinable
    static func `return`(_ block: () throws -> (Any)?) -> Bool {
        do {
            let result = try block()

            guard let result else {
                py.newnone(py.retval)
                return true
            }

            switch result {
            case let value as PythonConvertible:
                value.toPython(py.retval)

            default:
                SwiftObject(result).toPython(py.retval)
            }
            return true
        } catch let error as PythonError {
            return PyAPI.throw(error.type, error.value)
        } catch {
            return PyAPI.throw(.RuntimeError, error.localizedDescription)
        }
    }

    @inlinable
    static func `throw`(_ error: PyType, _ message: PythonConvertible?) -> Bool {
        let tmp = py.pushtmp()
        defer { py.pop() }
        message?.toPython(tmp)
        py_tpcall(error, 1, tmp)
        return py_raise(py.retval)
    }
}

public extension Interpreter {
    @inlinable func module(_ name: String) -> PyRef? {
        if let module = py.getmodule(name) {
            return module
        }

        return try? py.import(name)
    }
}

// MARK: - PyType

/// `Int16`
public typealias PyType = py_Type

// MARK: - Functions

public extension PyRef {
    @MainActor
    struct Functions {
        let eval = py_getbuiltin(py_name("eval"))!
        let exec = py_getbuiltin(py_name("exec"))!
    }
    
    @MainActor static let functions = Functions()
}

// MARK: - Reference extensions

@MainActor
public extension PyRef {
    @inlinable var userdata: UnsafeMutableRawPointer {
        py_touserdata(self)
    }

    @inlinable
    func toUserdata<T: PythonConvertible>(as type: T.Type = T.self) -> T {
        py_touserdata(self).assumingMemoryBound(to: T.self).pointee
    }
    
    @inlinable var isNil: Bool {
        py_istype(self, 0)
    }
    
    @inlinable var isNone: Bool {
        py_istype(self, PyType.None)
    }

    /// Copies the given value into the reference memory.
    @inlinable func assign(_ newValue: PyRef?) {
        guard let newValue else { return }
        pointee = newValue.pointee
    }
    
    /// Returns an `AnyView` if the bounded object implements `ViewRepresentable`.
    @inlinable
    var view: AnyView? {
        // Try AnyView. AnyView cannot be subclassed.
        if py.typeof(self) == AnyView.pyType,
           let view = AnyView(self) {
            return view
        }

        // Try View.
        if py.isinstance(self, type: .View),
           let body = try? py.getattr(self, name: "body") {
            let view = try? py.call(body)
            return view?.view
        }

        // Try self.__view__.
        let view = Interpreter.silenceErrors {
            try py.getattr(self, name: "__view__")
        }
        if let view {
            return AnyView(view)
        }

        return nil
    }

    @inlinable func setAttribute(_ name: String, _ value: PyRef?) {
        try? py.setattr(self, name: name, value: value)
    }
    
    @inlinable func emplace(_ name: String) -> PyRef {
        py_emplacedict(self, py_name(name))
    }

    @inlinable
    subscript(name: String) -> PyRef? {
        py.getdict(self, name: name)
    }
    
    @inlinable
    subscript(index: Int) -> PyRef? {
        advanced(by: index)
    }
    
    @inlinable
    subscript(slot i: Int32) -> PyRef? {
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

    @available(*, deprecated, renamed: "py.istype")
    @inlinable func isType<T: PythonConvertible>(_ type: T.Type) -> Bool {
        py.istype(self, type: T.pyType)
    }
    
    @available(*, deprecated, renamed: "py.isinstance")
    @inlinable func isInstance(of type: PyType) -> Bool {
        py.isinstance(self, type: type)
    }
    
    @inlinable
    func canCast(to type: PyType) -> Bool {
        if py.isinstance(self, type: type) {
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

@MainActor public extension PyRef? {
    @inlinable static func == <T: PythonConvertible>(lhs: PyRef?, rhs: T?) -> Bool where T: Equatable {
        T(lhs) == rhs
    }
}

@MainActor
public indirect enum PythonError: LocalizedError {
    case SyntaxError(PythonConvertible)
    case RecursionError(PythonConvertible)
    case OSError(PythonConvertible)
    case NotImplementedError(PythonConvertible)
    case TypeError(PythonConvertible)
    case IndexError(PythonConvertible)
    case ValueError(PythonConvertible)
    case RuntimeError(PythonConvertible)
    case ZeroDivisionError(PythonConvertible)
    case NameError(PythonConvertible)
    case UnboundLocalError(PythonConvertible)
    case AttributeError(PythonConvertible)
    case ImportError(PythonConvertible)
    case AssertionError(PythonConvertible)
    case KeyError(PythonConvertible)
    case StopIteration(PythonConvertible)
    case BaseException(PythonConvertible)
    
    static func argCountError(_ got: Int32, expected: Int) -> PythonError {
        .TypeError("expected \(expected) arguments, got \(got)")
    }
    
    public var value: PythonConvertible {
        switch self {
        case let .SyntaxError(value): value
        case let .RecursionError(value): value
        case let .OSError(value): value
        case let .NotImplementedError(value): value
        case let .TypeError(value): value
        case let .IndexError(value): value
        case let .ValueError(value): value
        case let .RuntimeError(value): value
        case let .ZeroDivisionError(value): value
        case let .NameError(value): value
        case let .UnboundLocalError(value): value
        case let .AttributeError(value): value
        case let .ImportError(value): value
        case let .AssertionError(value): value
        case let .KeyError(value): value
        case let .StopIteration(value): value
        case let .BaseException(value): value
        }
    }

    public var description: String? {
        String(describing: value)
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
        case .StopIteration: .StopIteration
        case .BaseException: .BaseException
        }
    }

    public static let pyType = PyType.BaseException
}

extension PythonError: PythonConvertible {
    // TODO: test
    public func toPython(_ reference: PyRef) {
        let error = try! py.call(py.tpobject(type)!, args: description)
        reference.assign(error)
    }
    
    public static func fromPython(_ reference: PyRef) -> PythonError {
        let type = py.typeof(reference)
        let args = Interpreter.silenceErrors {
            try py.getattr(reference, name: "args")
        }

        var ref: PyRef? = py_None()
        if let args, py.tuple.len(args) > 0 {
            ref = py.tuple.getitem(args, i: 0)
        }

        let value: PythonConvertible = if let str = String(ref) {
            str
        } else {
            ref
        }

        return switch type {
        case .SyntaxError: .SyntaxError(value)
        case .OSError: .OSError(value)
        case .NotImplementedError: .NotImplementedError(value)
        case .RecursionError: .RecursionError(value)
        case .RuntimeError: .RuntimeError(value)
        case .TypeError: .TypeError(value)
        case .IndexError: .IndexError(value)
        case .ValueError: .ValueError(value)
        case .ZeroDivisionError: .ZeroDivisionError(value)
        case .UnboundLocalError: .UnboundLocalError(value)
        case .NameError: .NameError(value)
        case .AttributeError: .AttributeError(value)
        case .ImportError: .ImportError(value)
        case .AssertionError: .AssertionError(value)
        case .KeyError: .KeyError(value)

        case .StopIteration: .StopIteration(value)
        default: .BaseException(value)
        }
    }
}
