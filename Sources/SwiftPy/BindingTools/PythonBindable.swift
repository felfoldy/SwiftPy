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
    static func __init__(_ argc: Int32, _ argv: PyAPI.Reference?, _ initializer: () -> Self) -> Bool {
        guard argc == 1 else { return false }
        initializer().storeInPython(argv)
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func __init__<Arg1: PythonConvertible>(_ argc: Int32, _ argv: PyAPI.Reference?, _ initializer: (Arg1) -> Self) -> Bool {
        guard argc == 2, let arg1 = Arg1(argv?[1]) else {
            return false
        }
        initializer(arg1).storeInPython(argv)
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func __repr__(_ argv: PyAPI.Reference?) -> Bool {
        if let obj = Self(argv) {
            return PyAPI.return(String(describing: obj))
        }
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func ensureArgument<T: PythonConvertible>(_ argv: PyAPI.Reference?, _ type: T.Type, block: (T) -> Void) -> Bool {
        if let value = T(argv) {
            block(value)
            return PyAPI.return(.none)
        }
        return T.throwTypeError(argv?[1], 1)
    }
    
    /// `(self, Arg1) -> Void`
    @inlinable static func ensureArguments<Arg1: PythonConvertible>(_ argv: PyAPI.Reference?, _ arg1: Arg1.Type, block: (inout Self, Arg1) -> Void) -> Bool {
        guard var obj = Self(argv) else {
            return .throwTypeError(argv, 0)
        }
        
        guard let value1 = Arg1(argv?[1]) else {
            return Arg1.throwTypeError(argv?[1], 1)
        }
        
        block(&obj, value1)
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func _bind_getter<Value: PythonConvertible>(_ keypath: WritableKeyPath<Self, Value>, _ argv: PyAPI.Reference?) -> Bool {
        PyAPI.return(Self(argv)?[keyPath: keypath])
    }
    
    @inlinable
    static func _bind_setter<Value: PythonConvertible>(_ keypath: WritableKeyPath<Self, Value>, _ argv: PyAPI.Reference?) -> Bool {
        ensureArguments(argv, Value.self) { base, value in
            base[keyPath: keypath] = value
        }
    }
    
    /// `() -> Void`
    @inlinable
    static func _bind_function(_ fn: (Self) -> () -> Void, _ argv: PyAPI.Reference?) -> Bool {
        guard let obj = Self(argv) else {
            return PyAPI.throw(.TypeError, "Invalid arguments")
        }
        fn(obj)()
        return PyAPI.return(.none)
    }
    
    /// `(Arg1) -> Void`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible>(_ fn: (Self) -> (Arg1) -> Void, _ argv: PyAPI.Reference?) -> Bool {
        guard let obj = Self(argv),
              let arg1 = Arg1(argv?[1]) else {
            return PyAPI.throw(.TypeError, "Invalid arguments")
        }
        fn(obj)(arg1)
        return PyAPI.return(.none)
    }
    
    /// `() -> Result?`
    @inlinable
    static func _bind_function(_ fn: (Self) -> () -> (any PythonConvertible)?, _ argv: PyAPI.Reference?) -> Bool {
        guard let obj = Self(argv) else {
            return PyAPI.throw(.TypeError, "Invalid arguments")
        }
        return PyAPI.return(fn(obj)())
    }
    
    @inlinable
    // @available(*, deprecated, message: "Use Slots instead.")
    static func cachedBinding(_ argv: PyAPI.Reference?, key: String, makeBinding: (Self) -> PythonBindable?) -> Bool {
        guard let obj = Self(argv) else {
            return .throwTypeError(argv, 0)
        }
        
        if let cached = obj._pythonCache.bindings[key] {
            return PyAPI.return(cached)
        }
        let binding = makeBinding(obj)
        obj._pythonCache.bindings[key] = binding
        return PyAPI.return(binding)
    }
    
    /// `(self, Arg1) -> Result?`
    @inlinable
    @available(*, deprecated, message: "Use `_bind_function` instead")
    static func ensureArguments<Arg1: PythonConvertible, Result: PythonConvertible>(_ argv: PyAPI.Reference?, _ arg1: Arg1.Type, block: (Self, Arg1) -> Result?) -> Bool {
        guard let obj = Self(argv) else {
            return .throwTypeError(argv, 0)
        }
        
        guard let value1 = Arg1(argv?[1]) else {
            return Arg1.throwTypeError(argv?[1], 1)
        }
        
        return PyAPI.return(block(obj, value1))
    }
}
