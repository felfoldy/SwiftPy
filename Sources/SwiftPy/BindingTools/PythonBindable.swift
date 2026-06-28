//
//  PythonBindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import SwiftUI

public protocol PythonValueBindable: PythonConvertible {}

@MainActor
public protocol PythonBindable: AnyObject, PythonValueBindable {
    var _pythonCache: PythonBindingCache { get set }
}

public struct PythonBindingCache {
    public var reference: PyRef?
    public init() {}
}

public extension PythonValueBindable {
    func toPython(_ reference: PyRef) {
        py.newobject(
            Optional(self),
            type: Self.pyType,
            out: reference,
            slots: -1
        )
    }

    @inlinable
    static func fromPython(_ reference: PyRef) -> Self {
        reference.toUserdata(as: Self?.self)!
    }

    @inlinable
    func storeInPython(_ reference: PyRef?) {
        reference?.userdata
            .assumingMemoryBound(to: Self?.self)
            .pointee = self
    }

    /// Creates a new object and initializes as `nil`.
    static func __new__(_ argv: PyRef?) -> Bool {
        let type = py.totype(argv)
        py.newobject(
            Self?.none,
            type: type,
            out: py.retval,
            slots: -1
        )
        return true
    }

    /// Binds an `init()`.
    @inlinable
    static func __init__(
        _ argv: PyRef?,
        _ initializer: @MainActor () throws -> Self
    ) -> Bool {
        PyAPI.return {
            PyBind.overloadArgumentsMatched = true
            try initializer().storeInPython(argv)
            return .none
        }
    }

    @inlinable
    static func __init__<each Arg: PythonConvertible>(
        _ argv: PyRef?,
        _ initializer: @MainActor (repeat each Arg) throws -> Self
    ) -> Bool {
        PyAPI.return {
            let result = try PyBind.castArgs(argv: argv, from: 1) as (repeat each Arg)
            try initializer(repeat (each result)).storeInPython(argv)
            return .none
        }
    }
    
    /// Binds an  `init(args)`.
    @inlinable
    static func __init__<each Arg: PythonConvertible>(
        _ argc: Int32, _ argv: PyRef?,
        _ initializer: @MainActor (repeat each Arg) throws -> Self
    ) -> Bool {
        PyAPI.return {
            let result = try PyBind.castArgs(argc: argc, argv: argv, from: 1) as (repeat each Arg)
            try initializer(repeat (each result)).storeInPython(argv)
            return .none
        }
    }

    @inlinable
    static func _bind_getter<Value>(_ keypath: KeyPath<Self, Value>, _ argv: PyRef?) -> Bool {
        PyAPI.return { Self(argv)?[keyPath: keypath] }
    }

    @inlinable
    static func _bind_setter<Value: PythonConvertible>(_ keypath: WritableKeyPath<Self, Value>, _ argv: PyRef?) -> Bool {
        PyAPI.return {
            var base = try cast(argv)
            let value = try Value.cast(argv, 1)
            base[keyPath: keypath] = value
            base.storeInPython(argv)
            return .none
        }
    }
}

public extension PythonBindable {
    @inlinable
    func storeInPython(_ reference: PyRef?, userdata: UnsafeMutableRawPointer? = nil) {
        guard let reference else { return }

        let userdata = userdata ?? reference.userdata
        
        // Store retained self pointer in python userdata.
        let retainedSelfPointer = Unmanaged.passRetained(self)
            .toOpaque()
        userdata.storeBytes(of: retainedSelfPointer, as: UnsafeRawPointer.self)

        // Store cache of python value.
        let pointer = PyRef.allocate(capacity: 1)
        pointer.initialize(to: reference.pointee)
        _pythonCache.reference = pointer
    }
    
    @inlinable
    func toPython(_ reference: PyRef) {
        if let cached = _pythonCache.reference {
            reference.assign(cached)
            return
        }

        let userdata = py.newobject(reference, type: Self.pyType, slots: -1)
        storeInPython(reference, userdata: userdata)
    }
    
    @inlinable
    static func fromPython(_ reference: PyRef) -> Self {
        let pointer = reference.userdata
            .load(as: UnsafeRawPointer.self)
        return Unmanaged<Self>.fromOpaque(pointer)
            .takeUnretainedValue()
    }
    
    @inlinable
    static func __repr__(_ argv: PyRef?) -> Bool {
        PyAPI.return {
            let obj = try cast(argv)
            return String(describing: obj)
        }
    }
}

// MARK: Binding helpers.

public extension PythonBindable {
    typealias object = PyRef

    @inlinable
    static func __new__(_ argv: PyRef?) -> Bool {
        let type = py.totype(argv)
        py.newobject(
            py.retval,
            type: type,
            slots: -1
        )
        return true
    }
    
    @inlinable
    static func _bind_setter<Value: PythonConvertible>(_ keypath: ReferenceWritableKeyPath<Self, Value>, _ argv: PyRef?) -> Bool {
        PyAPI.return {
            let base = try cast(argv)
            base[keyPath: keypath] = try Value.cast(argv, 1)
            return .none
        }
    }
    
    @inlinable
    static func _bind_setter<Value>(_ keypath: ReferenceWritableKeyPath<Self, Value>, _ argv: PyRef?) -> Bool {
        PyAPI.return {
            let anyValue = try SwiftObject.cast(argv, 1).value
            guard let value = anyValue as? Value else {
                throw PythonError.TypeError("Expected SwiftObject[\(Value.self)] at position \(1)")
            }
            let base = try cast(argv)
            base[keyPath: keypath] = value
            return .none
        }
    }
    
    // MARK: _bind_function
    
    /// `() -> Void`
    @inlinable
    static func _bind_function(
        _ argv: PyRef?,
        _ fn: (Self) -> () throws -> Void
    ) -> Bool {
        PyAPI.return {
            try fn(cast(argv))()
            return .none
        }
    }

    /// `() async -> Void`
    @inlinable
    static func _bind_function(
        _ argv: PyRef?,
        _ fn: @escaping (Self) -> () async throws -> Void
    ) -> Bool {
        PyAPI.return {
            let args = try cast(argv)
            return AsyncTask {
                try await fn(args)()
            }
        }
    }

    /// `() -> Result?`
    @inlinable
    static func _bind_function(
        _ argv: PyRef?,
        _ fn: (Self) -> () throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            try fn(cast(argv))()
        }
    }

    /// `() async -> Result?`
    @inlinable
    static func _bind_function<Result: PythonConvertible>(
        _ argv: PyRef?,
        _ fn: @escaping (Self) -> () async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.return {
            let args = try cast(argv)
            return AsyncTask {
                try await fn(args)()
            }
        }
    }

    /// `(...) -> Void`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ argv: PyRef?,
        _ arguments: (Self) -> (repeat each Arg) throws -> Void
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(argv)
            let result = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))
            try arguments(obj)(repeat (each result))
            return .none
        }
    }

    /// `(...) async -> Void`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ argv: PyRef?,
        _ fn: @escaping (Self) -> (repeat each Arg) async throws -> Void
    ) -> Bool where (repeat each Arg): Sendable {
        PyAPI.return {
            let obj = try cast(argv)
            let args = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))

            return AsyncTask {
                try await fn(obj)(repeat each args)
            }
        }
    }

    /// `(...) -> any`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ argv: PyRef?,
        _ arguments: (Self) -> (repeat each Arg) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(argv)
            let result = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))
            return try arguments(obj)(repeat (each result))
        }
    }
    
    /// `(...) async -> any`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible, Result: PythonConvertible>(
        _ argv: PyRef?,
        _ fn: @escaping (Self) -> (repeat each Arg) async throws -> Result
    ) -> Bool where Result: Sendable, (repeat each Arg): Sendable {
        PyAPI.return {
            let obj = try cast(argv)
            let args = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))
            
            return AsyncTask {
                try await fn(obj)(repeat each args)
            }
        }
    }
}
