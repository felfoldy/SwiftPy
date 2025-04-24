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
    
    deinit {
        py_pop()
    }
}

public extension PythonConvertible {
    var toStack: StackReference {
        StackReference(self)
    }
}

@MainActor
public extension PyAPI.Reference {
    var toStack: StackReference {
        StackReference(self)
    }
}
