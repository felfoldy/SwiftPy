//
//  StackReference.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-24.
//

import pocketpy

@MainActor
public class StackReference {
    public let reference: PyAPI.Reference?
    
    init(_ convertible: PythonConvertible) {
        reference = py_pushtmp()
        convertible.toPython(reference)
    }
    
    init(_ reference: PyAPI.Reference?) {
        self.reference = py_pushtmp()
        self.reference?.assign(reference)
    }
    
    public func iterate(next: (StackReference) throws -> Void) throws {
        try Interpreter.printErrors {
            py.iter(reference)
        }
        
        let iter = PyAPI.returnValue.retained
        
        while try Interpreter.printItemError(py_next(iter.reference)) {
            try next(PyAPI.returnValue.retained)
        }
    }

    deinit {
        py_pop()
    }
}

public extension PythonConvertible {
    @available(*, deprecated, renamed: "retained")
    var toStack: StackReference {
        StackReference(self)
    }

    /// Creates a temporary reference on stack.
    var retained: StackReference {
        StackReference(self)
    }
}

@MainActor
public extension PyAPI.Reference {
    @available(*, deprecated, renamed: "retained")
    var toStack: StackReference {
        StackReference(self)
    }

    /// Creates a temporary reference on stack.
    var retained: StackReference {
        StackReference(self)
    }
}
