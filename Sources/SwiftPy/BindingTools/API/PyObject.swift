@MainActor
private var nextID: Int32 = 0

@MainActor
private var freeSlots: [Int32] = []

/// A safe, reference-counted handle to a Python object.
///
/// A `PyObject` keeps the underlying Python value alive for as long as the instance exists, so
/// the reference is always valid while you hold it and won't be dereferenced out from under you.
///
/// Python attributes can be read and written using ordinary Swift member syntax, and the
/// subscripts bridge values to and from conforming Swift types:
///
/// ```swift
/// let module = py.module("math")
/// let pi: Double? = module.pi          // read attribute, cast to Swift
/// let result: Double = try module.sqrt(2.0)   // call a Python function
/// ```
@MainActor
@dynamicMemberLookup
public final class PyObject: @MainActor PyReferencing, Sendable {
    /// The underlying Python reference this handle keeps alive.
    public let reference: PyRef
    private let cacheID: Int32

    /// Creates a handle that retains the given Python reference.
    ///
    /// The reference is copied and held alive until this `PyObject` is deinitialized.
    ///
    /// - Parameter reference: The Python reference to retain.
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
    
    /// Accesses a Python attribute by name as another ``PyObject``.
    ///
    /// Reading returns `nil` if the attribute is missing or is Python's `None`. Writing sets
    /// the attribute on the underlying object.
    ///
    /// ```swift
    /// let pi = math.pi          // get attribute
    /// obj.value = otherObject   // set attribute
    /// ```
    ///
    /// - Parameter dynamicMember: The name of the Python attribute.
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

    /// Accesses a Python attribute by name, bridging it to a Swift type.
    ///
    /// Reading returns `nil` if the attribute is missing or cannot be converted to `Value`.
    /// Writing converts the Swift value to Python and assigns it.
    ///
    /// ```swift
    /// let pi: Double? = math.pi   // get and cast to Swift
    /// obj.count = 3               // convert and set
    /// ```
    ///
    /// - Parameter dynamicMember: The name of the Python attribute.
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
    
    /// Calls the underlying Python object, discarding any result.
    ///
    /// Use this when the object is callable and you don't need its return value.
    ///
    /// ```swift
    /// try printFunc("hello")
    /// ```
    ///
    /// - Parameter args: The arguments to pass to the call.
    /// - Throws: A ``PythonError`` if the call raises a Python exception.
    @inlinable
    public func callAsFunction(_ args: PythonConvertible?...) throws(PythonError) {
        try py.call(reference, args: args)
    }
    
    /// Calls the underlying Python object and returns the result as a ``PyObject``.
    ///
    /// - Parameter args: The arguments to pass to the call.
    /// - Returns: The call's result, or `nil` if it returned Python's `None`.
    /// - Throws: A ``PythonError`` if the call raises a Python exception.
    @discardableResult
    public func callAsFunction(_ args: PythonConvertible?...) throws(PythonError) -> PyObject? {
        let result = try py.retain(py.call(reference, args: args))
        #if DEBUG
        log.trace("call \(self.description) -> \(result.description)")
        #endif
        return result
    }
    
    /// Calls the underlying Python object and bridges the result to a Swift type.
    ///
    /// ```swift
    /// let root: Double = try math.sqrt(2.0)
    /// ```
    ///
    /// - Parameter args: The arguments to pass to the call.
    /// - Returns: The call's result converted to `Result`.
    /// - Throws: A ``PythonError`` if the call raises a Python exception or the result
    ///   cannot be converted to `Result`.
    @discardableResult
    public func callAsFunction<Result: PythonConvertible>(_ args: PythonConvertible?...) throws(PythonError) -> Result {
        let result = try py.retain(py.call(reference, args: args))
        #if DEBUG
        log.trace("call \(self.description) -> \(result.description)")
        #endif
        return try .cast(result.reference)
    }
    
    // MARK: Dictionary lookup.
    
    /// Accesses a dictionary item by key as a ``PyObject``.
    ///
    /// Reading returns the value stored for `key`, or `nil` if it isn't present. Writing
    /// stores `newValue` for `key`.
    ///
    /// - Parameter key: The dictionary key.
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
    
    /// Accesses a dictionary item by key, bridging the value to a Swift type.
    ///
    /// Reading returns the value stored for `key` converted to `Value`, or `nil` if it isn't
    /// present or can't be converted. Writing converts `newValue` to Python and stores it.
    ///
    /// - Parameter key: The dictionary key.
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

    /// Binds a Swift function to this object as a callable Python method.
    ///
    /// - Parameters:
    ///   - signature: The Python signature of the function, for example `"greet(name)"`.
    ///   - docs: An optional docstring exposed to Python.
    ///   - function: The Swift implementation invoked when Python calls the function.
    public func def(_ signature: String, docs: String? = nil, function: PyAPI.CFunction) {
        reference.bind(signature, docstring: docs, function: function)
    }
}

// MARK: - Convenience initializers.

public extension PyObject {
    /// Creates a handle from an optional reference, returning `nil` when it is `nil`.
    ///
    /// - Parameter reference: The Python reference to retain, or `nil`.
    convenience init?(_ reference: PyRef?) {
        guard let reference else { return nil }
        self.init(reference)
    }
    
    /// Creates a handle to the object representing a Python type.
    ///
    /// - Parameter type: The Python type to wrap.
    convenience init(_ type: PyType) {
        self.init(py.tpobject(type))!
    }
}

// MARK: - PyObject + PythonConvertible

extension PyObject: PythonConvertible, @MainActor CustomStringConvertible {
    /// A textual representation showing the object's Python type and address.
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
    /// Wraps an optional Python reference in a retaining ``PyObject``.
    ///
    /// - Parameter ref: The reference to retain, or `nil`.
    /// - Returns: A handle, or `nil` if `ref` is `nil`.
    @inlinable
    public func retain(_ ref: PyRef?) -> PyObject? {
        PyObject(ref)
    }

    /// Wraps a Python reference in a retaining ``PyObject``.
    ///
    /// - Parameter ref: The reference to retain.
    /// - Returns: A handle keeping the reference alive.
    @inlinable
    public func retain(_ ref: PyRef) -> PyObject {
        PyObject(ref)
    }
    
    /// Converts a Swift value to Python and wraps it in a retaining ``PyObject``.
    ///
    /// - Parameter value: The Swift value to bridge to Python.
    /// - Returns: A handle to the converted Python object.
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
