//
//  PyModule.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-05-25.
//

import pocketpy

@MainActor
@dynamicMemberLookup
public struct PyModule {
    public let reference: PyRef

    public init?(_ reference: PyRef?) {
        guard let reference else { return nil }
        self.reference = reference
    }
    
    @inlinable
    public subscript(dynamicMember dynamicMember: String) -> PyObject? {
        get {
            let attribute = Interpreter.silenceErrors {
                try py.getattr(reference, name: dynamicMember)
            }
            return PyObject(attribute)
        }
        nonmutating set {
            Interpreter.silenceErrors {
                try py.setattr(reference, name: dynamicMember, value: newValue?.reference)
            }
        }
    }
    
    @inlinable
    public subscript<Value: PythonConvertible>(dynamicMember dynamicMember: String) -> Value? {
        get {
            Interpreter.silenceErrors {
                try .cast(
                    py.getattr(reference, name: dynamicMember)
                )
            }
        }
        nonmutating set {
            Interpreter.silenceErrors {
                let tmp = py.pushtmp()
                defer { py.pop() }
                newValue?.toPython(tmp)
                try py.setattr(reference, name: dynamicMember, value: tmp)
            }
        }
    }

    public func def(_ signature: String, docstring: String? = nil, function: PyAPI.CFunction) {
        reference.bind(signature, function: function)
    }

    public func classes(_ types: PythonBindable.Type...) {
        for type in types { `class`(type) }
    }

    @discardableResult
    public func `class`(_ type: PythonBindable.Type) -> PyModule {
        let type = type.pyType
        py.setdict(reference, name: type.name, value: py.tpobject(type))
        return self
    }
}

public extension PyModule {
    @available(*, deprecated, renamed: "py.module")
    init?(_ name: String) {
        self.init(Interpreter.shared.module(name))
    }
    
    @available(*, deprecated, renamed: "py.main")
    static var main: PyModule {
        PyModule("__main__")!
    }
}

public extension PyAPI {
    func module(_ name: String) -> PyModule? {
        PyModule(Interpreter.shared.module(name))
    }
    
    var main: PyModule {
        module("__main__")!
    }
}
