//
//  ThrowingPyObject.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-13.
//

/// A view of a ``PyObject`` whose lookups and calls throw the Python
/// exception instead of folding it into `nil`.
///
/// ```swift
/// let root: Double = try sys.throwing.modules.get("math").sqrt(2.0)
/// ```
///
/// Missing attributes throw `AttributeError`; `None` comes back as an object,
/// so a typed read of it throws from the cast instead.
@MainActor
@dynamicMemberLookup
public struct ThrowingPyObject {
    public let object: PyObject

    public init(_ object: PyObject) {
        self.object = object
    }

    public subscript(dynamicMember name: String) -> ThrowingPyObject {
        get throws(PythonError) {
            ThrowingPyObject(py.retain(try py.getattr(object.reference, name: name)))
        }
    }

    @_disfavoredOverload
    public subscript<Value: PythonConvertible>(dynamicMember name: String) -> Value {
        get throws(PythonError) {
            try .cast(try py.getattr(object.reference, name: name))
        }
    }

    // A throwing getter rules out a setter, so writes are a method.
    public func set(_ name: String, to value: (any PythonConvertible)?) throws(PythonError) {
        let box = value.map { py.retain($0) } ?? nil
        try py.setattr(object.reference, name: name, value: box?.reference)
    }

    @discardableResult
    public func callAsFunction(_ args: (any PythonConvertible)?...) throws(PythonError) -> ThrowingPyObject {
        try call(unpacking: args)
    }

    @discardableResult
    @_disfavoredOverload
    public func callAsFunction<Result: PythonConvertible>(_ args: (any PythonConvertible)?...) throws(PythonError) -> Result {
        try call(unpacking: args)
    }

    /// The same calls with the arguments already in an array.
    @discardableResult
    public func call(unpacking args: [(any PythonConvertible)?]) throws(PythonError) -> ThrowingPyObject {
        ThrowingPyObject(py.retain(try py.call(object.reference, unpacking: args)))
    }

    @discardableResult
    @_disfavoredOverload
    public func call<Result: PythonConvertible>(unpacking args: [(any PythonConvertible)?]) throws(PythonError) -> Result {
        try .cast(try py.call(object.reference, unpacking: args))
    }
}

public extension PyObject {
    var throwing: ThrowingPyObject { ThrowingPyObject(self) }
}

public extension PyModule {
    var throwing: ThrowingPyObject { ThrowingPyObject(py.retain(reference)) }
}
