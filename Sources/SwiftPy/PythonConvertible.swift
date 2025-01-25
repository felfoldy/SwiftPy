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
    
    @inlinable public func toPython(_ reference: PyAPI.Reference?) {
        guard let reference else { return }
        self.toPython(reference)
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

// MARK: - Arrays.

// TODO: Add a generic solution?
extension [String]: PythonConvertible {
    public init?(_ reference: PyAPI.Reference) {
        guard reference.isType(Self.self) else { return nil }
        
        var items: [String] = []
        for i in 0 ..< py_list_len(reference) {
            if let str = String(py_list_getitem(reference, i)) {
                items.append(str)
            }
        }

        self = items
    }
    
    public func toPython(_ reference: PyAPI.Reference) {
        py_newlist(reference)
        let r0 = py_getreg(0)!
        for value in self {
            value.toPython(r0)
            py_list_append(reference, r0)
        }
    }
    
    public static let pyType = py_Type(tp_list.rawValue)
}
