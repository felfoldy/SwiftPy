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
                py_setattr(reference, py_name(dynamicMember), newValue?.reference ?? py_None())
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
                py_dict_getitem(reference, keyObject?.reference)
            )
            guard result == true else { return nil }
            return TempPyObject(PyAPI.returnValue)
        }
        set {
            let keyObject = TempPyObject(key)
            _ = Interpreter.ignoreErrors {
                py_dict_setitem(reference, keyObject?.reference, newValue?.reference ?? py_None())
            }
        }
    }

    /// Gets the item from a dictionary by a key and convert the value to a swift type.
    public subscript<Key: PythonConvertible, Value: PythonConvertible>(_ key: Key) -> Value? {
        get {
            Value(self[key]?.reference)
        }
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
        if !py_callable(reference) {
            throw PythonError.AssertionError("Object is not callable")
        }

        try Interpreter.printErrors {
            py_push(reference)
            
            py_pushnil() // Self object.
            
            var argc: UInt16 = 0
            for arg in args {
                if let arg {
                    arg.toPython(py_pushtmp())
                } else {
                    py_pushnone()
                }
                argc += 1
            }

            return py_vectorcall(argc, 0)
        }
    }
}

/// Creates a temporary reference on the stack.
///
/// Do not store it, should be deinited at the end of the scope.
public class TempPyObject: PyObject {
    public override init?(_ reference: PyAPI.Reference?) {
        guard let reference else { return nil }
        let temp = py_pushtmp()
        temp?.assign(reference)
        super.init(temp)
    }
    
    public init?<Value: PythonConvertible>(_ value: Value) {
        let temp = py_pushtmp()
        value.toPython(temp)
        super.init(temp)
    }

    deinit { py_pop() }
}

public class PyModule: PyObject {
    public init?(_ name: String) {
        let module = Interpreter.module(name)
        super.init(module)
    }
    
    public override subscript(dynamicMember dynamicMember: String) -> PyObject? {
        get {
            PyObject(reference[dynamicMember])
        }
        set {
            super[dynamicMember: dynamicMember] = newValue
        }
    }
}

public extension PyModule {
    static let main = PyModule("__main__")!
}
