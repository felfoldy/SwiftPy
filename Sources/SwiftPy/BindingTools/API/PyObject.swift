@MainActor
private var nextID: Int32 = 0

@MainActor
private var freeSlots: [Int32] = []

@MainActor
@dynamicMemberLookup
public final class PyObject: @MainActor PyReferencing, Sendable {
    public let reference: PyRef
    private let cacheID: Int32

    public init(_ reference: PyRef) {
        let copy = PyRef.allocate(capacity: 1)
        copy.initialize(to: reference.pointee)

        if let slot = freeSlots.popLast() {
            py.list.setitem(py.objectCache, i: slot, value: copy)
            cacheID = slot
        } else {
            py.list.append(py.objectCache, value: copy)
            cacheID = nextID
            nextID += 1
        }
        self.reference = copy
        #if DEBUG
        log.trace("retain \(self.description) index: \(self.cacheID)")
        #endif
    }

    @MainActor deinit {
        #if DEBUG
        log.trace("release \(self.description) index: \(self.cacheID)")
        #endif
        py.list.setitem(py.objectCache, i: cacheID, value: py.None())
        reference.deinitialize(count: 1)
        reference.deallocate()
        freeSlots.append(cacheID)
    }

    // MARK: Dynamic member lookup.
    
    @inlinable
    public subscript(dynamicMember dynamicMember: String) -> PyObject? {
        get {
            let attribute = try? Interpreter.silenceErrors {
                try py.getattr(reference, name: dynamicMember)
            }
            if attribute?.isNone == true {
                return nil
            }
            return PyObject(attribute)
        }
        set {
            try? Interpreter.silenceErrors {
                try py.setattr(reference, name: dynamicMember, value: newValue?.reference)
            }
        }
    }

    @inlinable
    public subscript<Value: PythonConvertible>(dynamicMember dynamicMember: String) -> Value? {
        get {
            try? Interpreter.silenceErrors {
                try .cast(
                    py.getattr(reference, name: dynamicMember)
                )
            }
        }
        set {
            try? Interpreter.silenceErrors {
                let tmp = py.pushtmp()
                defer { py.pop() }
                newValue?.toPython(tmp)
                try py.setattr(reference, name: dynamicMember, value: tmp)
            }
        }
    }

    // MARK: Functions
    
    @inlinable
    public func callAsFunction(_ args: PythonConvertible?...) throws(PythonError) {
        try py.call(reference, args: args)
    }
    
    @discardableResult
    public func callAsFunction(_ args: PythonConvertible?...) throws(PythonError) -> PyObject? {
        let result = try py.retain(py.call(reference, args: args))
        #if DEBUG
        log.trace("call \(self.description) -> \(result.description)")
        #endif
        return result
    }
    
    @discardableResult
    public func callAsFunction<Result: PythonConvertible>(_ args: PythonConvertible?...) throws(PythonError) -> Result {
        let result = try py.retain(py.call(reference, args: args))
        #if DEBUG
        log.trace("call \(self.description) -> \(result.description)")
        #endif
        return try .cast(result.reference)
    }
    
    // MARK: Dictionary lookup.
    
    /// Gets the item from a dictionary by a key.
    public subscript<Key: PythonConvertible>(_ key: Key) -> PyObject? {
        get {
            let keyObject = py.retain(key)
            let result = try? py.dict.getitem(reference, key: keyObject?.reference)
            return py.retain(result)
        }
        set {
            let keyObject = py.retain(key)
            _ = try? py.dict.setitem(
                reference,
                key: keyObject?.reference,
                value: newValue?.reference
            )
        }
    }
    
    /// Gets the item from a dictionary by a key and convert the value to a swift type.
    public subscript<Key: PythonConvertible, Value: PythonConvertible>(_ key: Key) -> Value? {
        get {
            try? Interpreter.silenceErrors {
                let key = py.retain(key)
                let item =  try py.dict.getitem(reference, key: key?.reference)
                return try .cast(item)
            }
        }
        set {
            try? Interpreter.silenceErrors {
                let value = py.retain(newValue)
                let key = py.retain(key)
                _ = try py.dict.setitem(
                    reference,
                    key: key?.reference,
                    value: value?.reference
                )
            }
        }
    }

    public func def(_ signature: String, docs: String? = nil, function: PyAPI.CFunction) {
        reference.bind(signature, docstring: docs, function: function)
    }
}

// MARK: - Convenience initializers.

public extension PyObject {
    convenience init?(_ reference: PyRef?) {
        guard let reference else { return nil }
        self.init(reference)
    }
    
    convenience init(_ type: PyType) {
        self.init(py.tpobject(type))!
    }
}

// MARK: - PyObject + PythonConvertible

extension PyObject: PythonConvertible, @MainActor CustomStringConvertible {
    public var description: String {
        "<\(reference.pointee.type.name) at \(reference)>"
    }
    
    public func toPython(_ reference: PyRef) {
        log.trace("toPython: \(self.description)")
        reference.assign(self.reference)
    }
    
    public static func fromPython(_ reference: PyRef) -> PyObject {
        let ref = PyObject(reference)
        log.trace("fromPython: \(ref.description)")
        return ref
    }
    
    public static let pyType = PyType.object
}

extension PyAPI {
    @inlinable
    public func retain(_ ref: PyRef?) -> PyObject? {
        PyObject(ref)
    }

    @inlinable
    public func retain(_ ref: PyRef) -> PyObject {
        PyObject(ref)
    }
    
    @inlinable
    public func retain<Value: PythonConvertible>(_ value: Value) -> PyObject? {
        let tmp = py.pushtmp()
        defer { py.pop() }
        value.toPython(tmp)
        return PyObject(tmp)
    }
}

extension PythonConvertible {
    init?(_ ref: PyObject?) {
        self.init(ref?.reference)
    }
}
