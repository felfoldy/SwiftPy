//
//  PythonBindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import pocketpy

public protocol PythonBindable: AnyObject, PythonConvertible {
    var _pythonCache: PythonBindingCache { get set }
}

public struct PythonBindingCache {
    public var reference: PyAPI.Reference?
    public var bindings: [String: PythonBindable] = [:]
    
    public init() {}
}

public extension PythonBindable {
    @inlinable static var slotCount: Int32 {
        let slots = (self as? (any HasSlots.Type))?.slotCount
        return Int32(slots ?? -1)
    }
    
    @inlinable
    func storeInPython(_ reference: PyAPI.Reference?, userdata: UnsafeMutableRawPointer? = nil) {
        let userdata = userdata ?? reference?.userdata
        
        // Store retained self pointer in python userdata.
        let retainedSelfPointer = Unmanaged.passRetained(self)
            .toOpaque()
        userdata?.storeBytes(of: retainedSelfPointer,
                             as: UnsafeRawPointer.self)
        
        // Store cache of python object.
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: 16, alignment: 8)
        let opaquePointer = OpaquePointer(pointer)
        opaquePointer.assign(reference)
        _pythonCache.reference = opaquePointer
    }
    
    /// Creates a new python object.
    /// - Parameters:
    ///   - reference: reference what will be initiated with a new object.
    ///   - hasDictionary: Creates a `__dict__`.
    /// - Returns: Reference to the userdata.
    @discardableResult
    @inlinable
    static func newPythonObject(_ reference: PyAPI.Reference) -> UnsafeMutableRawPointer {
        let ud = py_newobject(reference, pyType, slotCount, PyAPI.pointerSize)
        ud?.storeBytes(of: nil, as: UnsafeRawPointer?.self)
        return ud!
    }
    
    @inlinable
    func toPython(_ reference: PyAPI.Reference) {
        if let cached = _pythonCache.reference {
            reference.assign(cached)
            return
        }
        
        let userdata = Self.newPythonObject(reference)
        storeInPython(reference, userdata: userdata)
    }
    
    @inlinable
    static func fromPython(_ reference: PyAPI.Reference) -> Self {
        let pointer = reference.userdata
            .load(as: UnsafeRawPointer.self)
        return Unmanaged<Self>.fromOpaque(pointer)
            .takeUnretainedValue()
    }
}

// MARK: - Binding tools

public extension PythonConvertible {
    /// Throws generic `TypeError`.
    ///
    /// - Parameters:
    ///   - ref: result it got
    ///   - position: position
    /// - Returns: `false`
    @inlinable static func throwTypeError(_ ref: PyAPI.Reference?, _ position: Int) -> Bool {
        PyAPI.throw(.TypeError, "Expected \(pyType.name) got \(py_typeof(ref).name) at position \(position)")
    }
}

// MARK: Binding helpers.

public extension PythonBindable {
    @inlinable
    static func __new__(_ argv: PyAPI.Reference?) -> Bool {
        let type = py_totype(argv)
        let ud = py_newobject(PyAPI.returnValue, type, slotCount, PyAPI.pointerSize)
        // Clear ud so if init fails it won't try to deinit a random address.
        ud?.storeBytes(of: nil, as: UnsafeRawPointer?.self)
        return true
    }
    
    @inlinable
    static func __init__(
        _ argc: Int32, _ argv: PyAPI.Reference?,
        _ initializer: @MainActor () throws -> Self
    ) -> Bool {
        guard argc == 1 else { return false }
        return PyAPI.returnOrThrow {
            try initializer().storeInPython(argv)
        }
    }
    
    @inlinable
    static func __init__<each Arg: PythonConvertible>(
        _ argc: Int32, _ argv: PyAPI.Reference?,
        _ initializer: @MainActor (repeat each Arg) throws -> Self
    ) -> Bool {
        do {
            let result = try PyBind.checkArgs(argc: argc, argv: argv, from: 1) as (repeat each Arg)
            try initializer(repeat (each result)).storeInPython(argv)
        } catch {
            // TODO: incorrect when the error thrown by the init itself.
            return false
        }
        
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func __repr__(_ argv: PyAPI.Reference?) -> Bool {
        PyAPI.returnOrThrow {
            try String(describing: cast(argv))
        }
    }
    
    @inlinable
    static func _bind_getter<Value: PythonConvertible>(_ keypath: KeyPath<Self, Value>, _ argv: PyAPI.Reference?) -> Bool {
        PyAPI.return(Self(argv)?[keyPath: keypath])
    }
    
    @inlinable
    static func _bind_setter<Value: PythonConvertible>(_ keypath: ReferenceWritableKeyPath<Self, Value>, _ argv: PyAPI.Reference?) -> Bool {
        PyAPI.returnOrThrow {
            let base = try cast(argv)
            base[keyPath: keypath] = try PyBind.castArgs(argv: argv, from: 1)
            return ()
        }
    }
    
    // MARK: _bind_function
    
    /// `() -> Void`
    @inlinable
    static func _bind_function(
        _ argv: PyAPI.Reference?,
        _ fn: (Self) -> () throws -> Void
    ) -> Bool {
        PyAPI.returnOrThrow {
            try fn(cast(argv))()
        }
    }
    
    /// `() -> Result?`
    @inlinable
    static func _bind_function(
        _ argv: PyAPI.Reference?,
        _ fn: (Self) -> () throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.returnOrThrow {
            try fn(cast(argv))()
        }
    }
    
    /// `(...) -> Void`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ argv: PyAPI.Reference?,
        _ arguments: (Self) -> (repeat each Arg) throws -> Void
    ) -> Bool {
        PyAPI.returnOrThrow {
            let obj = try cast(argv)
            let result = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))
            return try arguments(obj)(repeat (each result))
        }
    }
    
    /// `(...) -> any`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ argv: PyAPI.Reference?,
        _ arguments: (Self) -> (repeat each Arg) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.returnOrThrow {
            let obj = try cast(argv)
            let result = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))
            return try arguments(obj)(repeat (each result))
        }
    }

    @inlinable
    static func __getitem__<Key: PythonConvertible>(_ argc: Int32, _ argv: PyAPI.Reference?, _ fn: (Self) -> (Key) -> any PythonConvertible) -> Bool {
        PyAPI.returnOrThrow {
            if argc != 2 {
                throw PythonError.ValueError("Expected 2 arguments, got \(argc)")
            }
            let obj = try cast(argv)
            let key = try Key.cast(argv?[1])
            return fn(obj)(key)
        }
    }
}
