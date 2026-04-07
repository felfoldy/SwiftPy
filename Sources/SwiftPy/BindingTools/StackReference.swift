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
        reference = py.pushtmp()
        convertible.toPython(reference)
    }
    
    init(_ reference: PyAPI.Reference?) {
        self.reference = py.pushtmp()
        self.reference?.assign(reference)
    }
    
    public func iterate(next: (StackReference) throws -> Void) throws {
        try Interpreter.printErrors {
            py.iter(reference)
        }
        
        let iter = TempPyObject(py.retval)
        
        while try Interpreter.printItemError(py.next(iter?.reference)) {
            try next(py.retval.retained)
        }
    }

    @MainActor deinit { py.pop() }
}

public extension PythonConvertible {
    /// Creates a temporary reference on stack.
    var retained: StackReference {
        StackReference(self)
    }
}

@MainActor
public extension PyAPI.Reference {
    /// Creates a temporary reference on stack.
    var retained: StackReference {
        StackReference(self)
    }
}
