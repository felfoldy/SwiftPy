//
//  PyObject.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-04-04.
//

import pocketpy

@MainActor
public final class PyCache {
    private var cacheID: Int32 = 0
    private var freeSlots: [Int32] = []
    private lazy var objectCache: PyRef = {
        PyModule("interpreter")!._swift_object_cache!
    }()
    
    /// Created as a singleton in `py.cache`
    init() {}
    
    public func add(_ value: PyRef) -> Int32 {
        guard let slot = freeSlots.popLast() else {
            py.list.append(objectCache, value: value)
            defer { cacheID += 1 }
            return cacheID
        }
        py.list.setitem(objectCache, i: slot, value: value)
        return slot
    }
    
    public func remove(at index: Int32) {
        py.list.setitem(objectCache, i: index, value: py_None())
        freeSlots.append(index)
    }
}

/// Wrapper to a `PyObject`.
@MainActor
@dynamicMemberLookup
public class PyObject {
    public let reference: PyAPI.Reference

    @usableFromInline
    let cacheID: Int32?

    @inlinable
    public init?(borrowing reference: PyAPI.Reference?) {
        guard let reference else { return nil }
        self.reference = reference
        cacheID = nil
    }
    
    @inlinable
    public init?(_ borrowed: PyRef?) {
        guard let borrowed else { return nil }
        reference = .allocate(capacity: 1)
        reference.initialize(to: borrowed.pointee)
        self.cacheID = Interpreter.cache.add(borrowed)
    }
    
    public convenience init(_ type: PyType) {
        self.init(py.tpobject(type))!
    }
    
    @MainActor deinit {
        if let cacheID {
            Interpreter.cache.remove(at: cacheID)
            reference.deinitialize(count: 1)
            reference.deallocate()
        }
    }

    /// Lookup for the attribute of the python object.
    public subscript(dynamicMember dynamicMember: String) -> PyObject? {
        get {
            let member = Interpreter.silenceErrors {
                try py.getattr(reference, name: dynamicMember)
            }
            
            if member?.isNone == true {
                return nil
            }
            return TempPyObject(member)
        }
        set {
            Interpreter.silenceErrors = true
            defer { Interpreter.silenceErrors = false }
            try? py.setattr(
                reference,
                name: dynamicMember,
                value: newValue?.reference
            )
        }
    }

    /// Lookup for the attribute of the python object and converts the value to a Swift type.
    public subscript<Value: PythonConvertible>(dynamicMember dynamicMember: String) -> Value? {
        get { Value(self[dynamicMember: dynamicMember]?.reference) }
        set { self[dynamicMember: dynamicMember] = TempPyObject(newValue) }
    }

    /// Gets the item from a dictionary by a key.
    public subscript<Key: PythonConvertible>(_ key: Key) -> PyObject? {
        get {
            let keyObject = TempPyObject(key)
            let result = try? py.dict.getitem(reference, key: keyObject?.reference)
            return TempPyObject(result)
        }
        set {
            let keyObject = TempPyObject(key)
            _ = try? py.dict.setitem(
                reference,
                key: keyObject?.reference,
                value: newValue?.reference
            )
        }
    }

    /// Gets the item from a dictionary by a key and convert the value to a swift type.
    public subscript<Key: PythonConvertible, Value: PythonConvertible>(_ key: Key) -> Value? {
        get { Value(self[key]?.reference) }
        set { self[key] = TempPyObject(newValue) }
    }
    
    public func callAsFunction(_ args: PythonConvertible?...) throws {
        try py.call(reference, args: args)
    }
    
    @discardableResult
    public func callAsFunction<Value: PythonConvertible>(_ args: PythonConvertible?...) throws -> Value {
        let result = try py.call(reference, args: args)
        return try Value.cast(result)
    }
}

/// Creates a temporary reference on the stack.
///
/// Do not store it, should be deinited at the end of the scope.
public class TempPyObject: PyObject {
    public override init?(_ reference: PyAPI.Reference?) {
        guard let reference else { return nil }
        let temp = py.pushtmp()
        temp.assign(reference)
        super.init(borrowing: temp)
    }
    
    @inlinable
    public init?<Value: PythonConvertible>(_ value: Value) {
        let temp = py.pushtmp()
        value.toPython(temp)
        super.init(borrowing: temp)
    }

    @MainActor deinit { py.pop() }
}

public class PyModule: PyObject {
    public init?(_ name: String) {
        let module = Interpreter.shared.module(name)
        super.init(borrowing: module)
    }
    
    public override init?(_ reference: PyAPI.Reference?) {
        super.init(borrowing: reference)
    }
    
    public override subscript(dynamicMember dynamicMember: String) -> PyObject? {
        get {
            PyObject(borrowing: reference[dynamicMember])
        }
        set {
            super[dynamicMember: dynamicMember] = newValue
        }
    }

    @discardableResult
    public func `class`(_ type: PythonBindable.Type) -> PyModule {
        let type = type.pyType
        py.setdict(reference, name: type.name, value: py.tpobject(type))
        return self
    }

    public func classes(_ types: PythonBindable.Type...) {
        for type in types { `class`(type) }
    }
    
    public func def(_ signature: String, docstring: String? = nil, function: PyAPI.CFunction) {
        reference.bind(signature, function: function)
    }
}

public extension PyModule {
    static let main = PyModule("__main__")!
}
