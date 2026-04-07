//
//  PythonBindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import pocketpy

@MainActor
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
        guard let reference else { return }

        let userdata = userdata ?? reference.userdata
        
        // Store retained self pointer in python userdata.
        let retainedSelfPointer = Unmanaged.passRetained(self)
            .toOpaque()
        userdata.storeBytes(of: retainedSelfPointer, as: UnsafeRawPointer.self)

        // Store cache of python value.
        let pointer = PyAPI.Reference.allocate(capacity: 1)
        pointer.initialize(to: reference.pointee)
        _pythonCache.reference = pointer
    }
    
    @inlinable
    func toPython(_ reference: PyAPI.Reference) {
        if let cached = _pythonCache.reference {
            reference.assign(cached)
            return
        }

        let userdata = py.newobject(reference, type: Self.pyType, slots: Self.slotCount)
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
        PyAPI.throw(.TypeError, "Expected \(pyType.name) got \(py.typeof(ref).name) at position \(position)")
    }
}

// MARK: Binding helpers.

public extension PythonBindable {
    typealias object = PyAPI.Reference

    @inlinable
    static func __new__(_ argv: PyAPI.Reference?) -> Bool {
        let type = py.totype(argv)
        py.newobject(
            py.retval,
            type: type,
            slots: slotCount
        )
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
        var result: (repeat each Arg)
        do {
            result = try PyBind.checkArgs(argc: argc, argv: argv, from: 1) as (repeat each Arg)
            do {
                try initializer(repeat (each result)).storeInPython(argv)
            } catch {
                // TODO: Should throw the error.
                return false
            }
        } catch {
            return false
        }
        
        return PyAPI.return(.none)
    }
    
    @inlinable
    static func __init__(
        _ argc: Int32, _ argv: PyAPI.Reference?,
        _ initializer: @MainActor (PyArguments) throws -> Self
    ) -> Bool {
        do {
            try initializer(PyArguments(argc: argc, argv: argv))
                .storeInPython(argv)
        } catch {
            // TODO: incorrect when the error thrown by the init itself.
            return false
        }

        return PyAPI.return(.none)
    }
    
    @inlinable
    static func __repr__(_ argv: PyAPI.Reference?) -> Bool {
        PyAPI.returnOrThrow {
            let obj = try cast(argv)
            return String(describing: obj)
        }
    }

    @inlinable
    static func __view__(_ argv: PyAPI.Reference?) -> Bool {
        PyAPI.returnOrThrow {
            if Self.self is (any ViewRepresentable.Type) {
                let obj = try cast(argv) as? (any ViewRepresentable)
                return obj?.representation
            }
            return nil
        }
    }
    
    @inlinable
    static func _bind_getter<Value>(_ keypath: KeyPath<Self, Value>, _ argv: PyAPI.Reference?) -> Bool {
        PyAPI.return(Self(argv)?[keyPath: keypath])
    }

    @inlinable
    static func _bind_setter<Value: PythonConvertible>(_ keypath: ReferenceWritableKeyPath<Self, Value>, _ argv: PyAPI.Reference?) -> Bool {
        PyAPI.returnOrThrow {
            let base = try cast(argv)
            base[keyPath: keypath] = try Value.cast(argv, 1)
            return
        }
    }
    
    @inlinable
    static func _bind_setter<Value>(_ keypath: ReferenceWritableKeyPath<Self, Value>, _ argv: PyAPI.Reference?) -> Bool {
        PyAPI.returnOrThrow {
            let anyValue = try SwiftObject.cast(argv, 1).value
            guard let value = anyValue as? Value else {
                throw PythonError.TypeError("Expected SwiftObject[\(Value.self)] at position \(1)")
            }
            let base = try cast(argv)
            base[keyPath: keypath] = value
            return
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

    /// `() async -> Void`
    @inlinable
    static func _bind_function(
        _ argv: PyAPI.Reference?,
        _ fn: @escaping (Self) -> () async throws -> Void
    ) -> Bool {
        PyAPI.returnOrThrow {
            let args = try cast(argv)
            return AsyncTask {
                try await fn(args)()
            }
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

    /// `() async -> Result?`
    @inlinable
    static func _bind_function<Result: PythonConvertible>(
        _ argv: PyAPI.Reference?,
        _ fn: @escaping (Self) -> () async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.returnOrThrow {
            let args = try cast(argv)
            return AsyncTask {
                try await fn(args)()
            }
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

    /// `(...) async -> Void`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ argv: PyAPI.Reference?,
        _ fn: @escaping (Self) -> (repeat each Arg) async throws -> Void
    ) -> Bool where (repeat each Arg): Sendable {
        PyAPI.returnOrThrow {
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
        _ argv: PyAPI.Reference?,
        _ arguments: (Self) -> (repeat each Arg) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.returnOrThrow {
            let obj = try cast(argv)
            let result = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))
            return try arguments(obj)(repeat (each result))
        }
    }
    
    /// `(...) async -> any`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible, Result: PythonConvertible>(
        _ argv: PyAPI.Reference?,
        _ fn: @escaping (Self) -> (repeat each Arg) async throws -> Result
    ) -> Bool where Result: Sendable, (repeat each Arg): Sendable {
        PyAPI.returnOrThrow {
            let obj = try cast(argv)
            let args = try PyBind.castArgs(argv: argv, from: 1) as (repeat (each Arg))
            
            return AsyncTask {
                try await fn(obj)(repeat each args)
            }
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
