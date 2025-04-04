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
    @available(*, deprecated, message: "Use `make(_:base:module:bind:)` and it wont be needed.")
    @inlinable static func deinitFromPython(_ userdata: UnsafeMutableRawPointer?) {
        guard let pointer = userdata?.load(as: UnsafeRawPointer?.self) else {
            return
        }

        // Tale retained value.
        let unmanaged = Unmanaged<Self>.fromOpaque(pointer)
        let obj = unmanaged.takeRetainedValue()

        // Clear cache.
        UnsafeRawPointer(obj._pythonCache.reference)?.deallocate()
        obj._pythonCache.reference = nil
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
    static func newPythonObject(_ reference: PyAPI.Reference, hasDictionary: Bool = false) -> UnsafeMutableRawPointer {
        let ud = py_newobject(reference, pyType, hasDictionary ? -1 : 0, PyAPI.pointerSize)
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

public extension PythonBindable {
    @inlinable static func cachedBinding(_ argv: PyAPI.Reference?, key: String, makeBinding: (Self) -> PythonBindable?) -> Bool {
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
    
    @inlinable static func reprDescription(_ argv: PyAPI.Reference?) -> Bool {
        if let obj = Self(argv) {
            return PyAPI.return(String(describing: obj))
        }
        return PyAPI.return(.none)
    }
    
    @inlinable static func ensureArgument<T: PythonConvertible>(_ argv: PyAPI.Reference?, _ type: T.Type, block: (T) -> Void) -> Bool {
        if let value = T(argv) {
            block(value)
            return PyAPI.return(.none)
        }
        return T.throwTypeError(argv?[1], 1)
    }
    
    /// `(self, Arg1) -> Void`
    @inlinable static func ensureArguments<Arg1: PythonConvertible>(_ argv: PyAPI.Reference?, _ arg1: Arg1.Type, block: (Self, Arg1) -> Void) -> Bool {
        guard let obj = Self(argv) else {
            return .throwTypeError(argv, 0)
        }
        
        guard let value1 = Arg1(argv?[1]) else {
            return Arg1.throwTypeError(argv?[1], 1)
        }

        block(obj, value1)
        return PyAPI.return(.none)
    }
    
    /// `(self, Arg1) -> Result?`
    @inlinable static func ensureArguments<Arg1: PythonConvertible, Result: PythonConvertible>(_ argv: PyAPI.Reference?, _ arg1: Arg1.Type, block: (Self, Arg1) -> Result?) -> Bool {
        guard let obj = Self(argv) else {
            return .throwTypeError(argv, 0)
        }
        
        guard let value1 = Arg1(argv?[1]) else {
            return Arg1.throwTypeError(argv?[1], 1)
        }
        
        return PyAPI.return(block(obj, value1))
    }
}
