//
//  PyObject.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-04-04.
//

import pocketpy

/// Wrapper to a `PyObject`.
@MainActor
@dynamicMemberLookup
public class PyObject {
    public let reference: PyAPI.Reference

    public init?(_ reference: PyAPI.Reference?) {
        guard let reference else { return nil }
        self.reference = reference
    }
    
    public convenience init?(_ type: PyType) {
        self.init(type.object)
    }

    /// Lookup for the attribute of the python object.
    public subscript(dynamicMember dynamicMember: String) -> PyObject? {
        get {
            let member = reference.attributeOrNil(dynamicMember)
            if member?.isNone == true {
                return nil
            }
            return TempPyObject(member)
        }
        set {
            _ = Interpreter.ignoreErrors {
                py.setattr(reference, name: dynamicMember, value: newValue?.reference)
            }
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
            let result = try? Interpreter.printItemError(
                py.dict.getitem(reference, key: keyObject?.reference)
            )
            guard result == true else { return nil }
            return TempPyObject(PyAPI.returnValue)
        }
        set {
            let keyObject = TempPyObject(key)
            _ = Interpreter.ignoreErrors {
                py.dict.setitem(reference, key: keyObject?.reference, value: newValue?.reference)
            }
        }
    }

    /// Gets the item from a dictionary by a key and convert the value to a swift type.
    public subscript<Key: PythonConvertible, Value: PythonConvertible>(_ key: Key) -> Value? {
        get { Value(self[key]?.reference) }
        set { self[key] = TempPyObject(newValue) }
    }
    
    public func callAsFunction(_ args: PythonConvertible?...) throws {
        try call(args)
    }
    
    @discardableResult
    public func callAsFunction<Value: PythonConvertible>(_ args: PythonConvertible?...) throws -> Value {
        try call(args)
        return try Value.cast(PyAPI.returnValue)
    }
    
    private func call(_ args: [PythonConvertible?]) throws {
        if !py.callable(reference) {
            throw PythonError.AssertionError("Object is not callable")
        }

        try Interpreter.printErrors {
            py.push(reference)
            
            py.pushnil() // Self object.
            
            var argc: UInt16 = 0
            for arg in args {
                if let arg {
                    arg.toPython(py.pushtmp())
                } else {
                    py.pushnone()
                }
                argc += 1
            }

            return py.vectorcall(argc: argc, kwargc: 0)
        }
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
        super.init(temp)
    }
    
    public init?<Value: PythonConvertible>(_ value: Value) {
        let temp = py.pushtmp()
        value.toPython(temp)
        super.init(temp)
    }

    @MainActor deinit { py.pop() }
}

public class PyModule: PyObject {
    public init?(_ name: String) {
        let module = Interpreter.module(name)
        super.init(module)
    }
    
    public override init?(_ reference: PyAPI.Reference?) {
        super.init(reference)
    }
    
    public override subscript(dynamicMember dynamicMember: String) -> PyObject? {
        get {
            PyObject(reference[dynamicMember])
        }
        set {
            super[dynamicMember: dynamicMember] = newValue
        }
    }

    @discardableResult
    public func `class`(_ type: PythonBindable.Type) -> PyModule {
        let type = type.pyType
        py.setdict(reference, name: type.name, value: type.object)
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
