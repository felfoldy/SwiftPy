//
//  PythonBindable+Storage.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import pocketpy

// How a bound object is laid out in Python is the backend's business: the
// userdata slot, the cache, and what `__new__` allocates. Everything above
// this -- the argument marshalling -- is shared.

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
    static func __new__(_ arguments: PyArguments) -> PyReturn {
        let type = py.totype(arguments[0])
        py.newobject(
            Self?.none,
            type: type,
            out: py.retval,
            slots: -1
        )
        return true
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
    static func __new__(_ arguments: PyArguments) -> PyReturn {
        let type = py.totype(arguments[0])
        py.newobject(
            py.retval,
            type: type,
            slots: -1
        )
        return true
    }
}
