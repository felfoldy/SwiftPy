//
//  PyModule.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-05-25.
//

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
            let attribute = try? Interpreter.silenceErrors {
                try py.getattr(reference, name: dynamicMember)
            }
            return PyObject(attribute)
        }
        nonmutating set {
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
        nonmutating set {
            try? Interpreter.silenceErrors {
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
    public func `class`(_ type: PythonValueBindable.Type) -> PyModule {
        let type = type.pyType
        py.setdict(reference, name: type.name, value: py.tpobject(type))
        return self
    }
}

extension PyModule: PythonConvertible {
    public static let pyType = PyType.module

    public static func fromPython(_ reference: PyRef) -> PyModule {
        PyModule(reference)!
    }

    public func toPython(_ reference: PyRef) {
        reference.assign(reference)
    }
}

extension PyModule {
    init?(_ name: String) {
        if let module = py.getmodule(name) {
            self.init(module)
            return
        }
        guard let imported = try? py.import(name) else {
            return nil
        }
        self.init(imported)
    }
}

public extension PyAPI {
    func module(_ name: String) -> PyModule? {
        PyModule(name)
    }
    
    var main: PyModule {
        module("__main__")!
    }
}
