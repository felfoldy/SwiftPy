//
//  PythonBindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import PocketPython

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
    static func __new__(_ arguments: PyArguments) -> Bool {
        let type = py.totype(arguments[0])
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
        _ arguments: PyArguments,
        _ initializer: @MainActor () throws -> Self
    ) -> Bool {
        PyAPI.return {
            PyBind.overloadArgumentsMatched = true
            try initializer().storeInPython(arguments[0])
            return .none
        }
    }

#if swift(<6.4)
    // Concrete overloads — work around "reabstraction of pack values" ICE in Swift 6.3.
    // Remove this entire block when upgrading to Swift 6.4.

    @inlinable
    static func __init__<Arg1: PythonConvertible>(
        _ arguments: PyArguments,
        _ initializer: @MainActor (Arg1) throws -> Self
    ) -> Bool {
        PyAPI.return {
            let arg1 = try Arg1.cast(arguments, 1)
            PyBind.overloadArgumentsMatched = true
            try initializer(arg1).storeInPython(arguments[0])
            return .none
        }
    }

    @inlinable
    static func __init__<Arg1: PythonConvertible, Arg2: PythonConvertible>(
        _ arguments: PyArguments,
        _ initializer: @MainActor (Arg1, Arg2) throws -> Self
    ) -> Bool {
        PyAPI.return {
            let arg1 = try Arg1.cast(arguments, 1)
            let arg2 = try Arg2.cast(arguments, 2)
            PyBind.overloadArgumentsMatched = true
            try initializer(arg1, arg2).storeInPython(arguments[0])
            return .none
        }
    }

    @inlinable
    static func __init__<Arg1: PythonConvertible, Arg2: PythonConvertible, Arg3: PythonConvertible>(
        _ arguments: PyArguments,
        _ initializer: @MainActor (Arg1, Arg2, Arg3) throws -> Self
    ) -> Bool {
        PyAPI.return {
            let arg1 = try Arg1.cast(arguments, 1)
            let arg2 = try Arg2.cast(arguments, 2)
            let arg3 = try Arg3.cast(arguments, 3)
            PyBind.overloadArgumentsMatched = true
            try initializer(arg1, arg2, arg3).storeInPython(arguments[0])
            return .none
        }
    }
#endif

    /// Binds an `init(args)`.
    @inlinable
    static func __init__<each Arg: PythonConvertible>(
        _ arguments: PyArguments,
        _ initializer: @MainActor (repeat each Arg) throws -> Self
    ) -> Bool {
        PyAPI.return {
            let result = try PyBind.castArgs(arguments, from: 1) as (repeat each Arg)
            try initializer(repeat (each result)).storeInPython(arguments[0])
            return .none
        }
    }

    @inlinable
    static func _bind_getter<Value>(_ keypath: KeyPath<Self, Value>, _ arguments: PyArguments) -> Bool {
        PyAPI.return { Self(arguments[0])?[keyPath: keypath] }
    }

    @inlinable
    static func _bind_setter<Value: PythonConvertible>(_ keypath: WritableKeyPath<Self, Value>, _ arguments: PyArguments) -> Bool {
        PyAPI.return {
            var base = try cast(arguments, 0)
            let value = try Value.cast(arguments, 1)
            base[keyPath: keypath] = value
            base.storeInPython(arguments[0])
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
    static func __repr__(_ arguments: PyArguments) -> Bool {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            return String(describing: obj)
        }
    }
}

// MARK: Binding helpers.

public extension PythonBindable {
    typealias object = PyRef

    @inlinable
    static func __new__(_ arguments: PyArguments) -> Bool {
        let type = py.totype(arguments[0])
        py.newobject(
            py.retval,
            type: type,
            slots: -1
        )
        return true
    }

    @inlinable
    static func _bind_setter<Value: PythonConvertible>(_ keypath: ReferenceWritableKeyPath<Self, Value>, _ arguments: PyArguments) -> Bool {
        PyAPI.return {
            let base = try cast(arguments, 0)
            base[keyPath: keypath] = try Value.cast(arguments, 1)
            return .none
        }
    }

    @inlinable
    static func _bind_setter<Value>(_ keypath: ReferenceWritableKeyPath<Self, Value>, _ arguments: PyArguments) -> Bool {
        PyAPI.return {
            let anyValue = try SwiftObject.cast(arguments, 1).value
            guard let value = anyValue as? Value else {
                throw PythonError.TypeError("Expected SwiftObject[\(Value.self)] at position \(1)")
            }
            let base = try cast(arguments, 0)
            base[keyPath: keypath] = value
            return .none
        }
    }

    // MARK: _bind_function

    /// `() -> Void`
    @inlinable
    static func _bind_function(
        _ arguments: PyArguments,
        _ fn: (Self) -> () throws -> Void
    ) -> Bool {
        PyAPI.return {
            try fn(cast(arguments, 0))()
            return .none
        }
    }

    /// `() async -> Void`
    @inlinable
    static func _bind_function(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> () async throws -> Void
    ) -> Bool {
        PyAPI.return {
            let args = try cast(arguments, 0)
            return AsyncTask {
                try await fn(args)()
            }
        }
    }

    /// `() -> Result?`
    @inlinable
    static func _bind_function(
        _ arguments: PyArguments,
        _ fn: (Self) -> () throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            try fn(cast(arguments, 0))()
        }
    }

    /// `() async -> Result?`
    @inlinable
    static func _bind_function<Result: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> () async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.return {
            let args = try cast(arguments, 0)
            return AsyncTask {
                try await fn(args)()
            }
        }
    }

#if swift(<6.4)
    // Concrete overloads — work around "reabstraction of pack values" ICE in Swift 6.3.
    // Remove this entire block when upgrading to Swift 6.4.

    /// `(Arg) -> Void`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: (Self) -> (Arg1) throws -> Void
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            try fn(obj)(arg1)
            return .none
        }
    }

    /// `(Arg) async -> Void`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> (Arg1) async throws -> Void
    ) -> Bool where Arg1: Sendable {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            return AsyncTask {
                try await fn(obj)(arg1)
            }
        }
    }

    /// `(Arg) -> any`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: (Self) -> (Arg1) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            return try fn(obj)(arg1)
        }
    }

    /// `(Arg) async -> Result`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible, Result: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> (Arg1) async throws -> Result
    ) -> Bool where Result: Sendable, Arg1: Sendable {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            return AsyncTask {
                try await fn(obj)(arg1)
            }
        }
    }

    /// `(Arg1, Arg2) -> Void`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible, Arg2: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: (Self) -> (Arg1, Arg2) throws -> Void
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            let arg2 = try Arg2.cast(arguments, 2)
            try fn(obj)(arg1, arg2)
            return .none
        }
    }

    /// `(Arg1, Arg2) async -> Void`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible, Arg2: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> (Arg1, Arg2) async throws -> Void
    ) -> Bool where Arg1: Sendable, Arg2: Sendable {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            let arg2 = try Arg2.cast(arguments, 2)
            return AsyncTask {
                try await fn(obj)(arg1, arg2)
            }
        }
    }

    /// `(Arg1, Arg2) -> any`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible, Arg2: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: (Self) -> (Arg1, Arg2) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            let arg2 = try Arg2.cast(arguments, 2)
            return try fn(obj)(arg1, arg2)
        }
    }

    /// `(Arg1, Arg2) async -> Result`
    @inlinable
    static func _bind_function<Arg1: PythonConvertible, Arg2: PythonConvertible, Result: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> (Arg1, Arg2) async throws -> Result
    ) -> Bool where Result: Sendable, Arg1: Sendable, Arg2: Sendable {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let arg1 = try Arg1.cast(arguments, 1)
            let arg2 = try Arg2.cast(arguments, 2)
            return AsyncTask {
                try await fn(obj)(arg1, arg2)
            }
        }
    }
#endif

    /// `(...) -> Void`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: (Self) -> (repeat each Arg) throws -> Void
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let result = try PyBind.castArgs(arguments, from: 1) as (repeat (each Arg))
            try fn(obj)(repeat (each result))
            return .none
        }
    }

    /// `(...) async -> Void`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> (repeat each Arg) async throws -> Void
    ) -> Bool where (repeat each Arg): Sendable {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let args = try PyBind.castArgs(arguments, from: 1) as (repeat (each Arg))

            return AsyncTask {
                try await fn(obj)(repeat each args)
            }
        }
    }

    /// `(...) -> any`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: (Self) -> (repeat each Arg) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let result = try PyBind.castArgs(arguments, from: 1) as (repeat (each Arg))
            return try fn(obj)(repeat (each result))
        }
    }

    /// `(...) async -> any`
    @inlinable
    static func _bind_function<each Arg: PythonConvertible, Result: PythonConvertible>(
        _ arguments: PyArguments,
        _ fn: @escaping (Self) -> (repeat each Arg) async throws -> Result
    ) -> Bool where Result: Sendable, (repeat each Arg): Sendable {
        PyAPI.return {
            let obj = try cast(arguments, 0)
            let args = try PyBind.castArgs(arguments, from: 1) as (repeat (each Arg))

            return AsyncTask {
                try await fn(obj)(repeat each args)
            }
        }
    }
}
