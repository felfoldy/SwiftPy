//
//  PythonConvertible.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import pocketpy

@MainActor
public protocol PythonConvertible {
    @inlinable init?(_ reference: PyAPI.Reference)
    @inlinable func toPython(_ reference: PyAPI.Reference)
}

extension PythonConvertible {
    @inlinable public init?(_ reference: PyAPI.Reference?) {
        guard let reference else { return nil }
        self.init(reference)
    }
    
    @inlinable public func toPython(_ reference: PyAPI.Reference?) {
        guard let reference else { return }
        self.toPython(reference)
    }
}

extension Bool: PythonConvertible {
    public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(.bool) else { return nil }
        self = py_tobool(reference)
    }

    public func toPython(_ reference: PyAPI.Reference) {
        py_newbool(reference, self)
    }
}

extension Int: PythonConvertible {
    public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(.int) else { return nil }
        self = Int(py_toint(reference))
    }

    public func toPython(_ reference: PyAPI.Reference) {
        py_newint(reference, py_i64(self))
    }
}

extension String: PythonConvertible {
    public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(.str) else { return nil }
        self = String(cString: py_tostr(reference))
    }

    public func toPython(_ reference: PyAPI.Reference) {
        py_newstr(reference, self)
    }
}

extension Double: PythonConvertible {
    public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(.float) else { return nil }
        self = Double(py_tofloat(reference))
    }

    public func toPython(_ reference: PyAPI.Reference) {
        py_newfloat(reference, self)
    }
}
