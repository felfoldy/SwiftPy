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

    static var pyType: py_Type { get }
}

extension PythonConvertible {
    @inlinable public init?(_ reference: PyAPI.Reference?) {
        guard let reference else { return nil }
        self.init(reference)
    }
}

extension Bool: PythonConvertible {
    @inlinable public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(Self.self) else { return nil }
        self = py_tobool(reference)
    }

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newbool(reference, self)
    }

    public static let pyType = py_Type(tp_bool.rawValue)
}

extension Int: PythonConvertible {
    @inlinable public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(Self.self) else { return nil }
        self = Int(py_toint(reference))
    }

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newint(reference, py_i64(self))
    }

    public static let pyType = py_Type(tp_int.rawValue)
}

extension String: PythonConvertible {
    @inlinable public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(Self.self) else { return nil }
        self = String(cString: py_tostr(reference))
    }

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newstr(reference, self)
    }

    public static let pyType = py_Type(tp_str.rawValue)
}

extension Double: PythonConvertible {
    @inlinable public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(Self.self) else { return nil }
        self = Double(py_tofloat(reference))
    }

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newfloat(reference, self)
    }

    public static let pyType = py_Type(tp_float.rawValue)
}
