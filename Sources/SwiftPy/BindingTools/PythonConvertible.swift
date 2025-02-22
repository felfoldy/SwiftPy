//
//  PythonConvertible.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import pocketpy

@MainActor
public protocol PythonConvertible {
    @inlinable mutating func toPython(_ reference: PyAPI.Reference)
    @inlinable static func fromPython(_ reference: PyAPI.Reference) -> Self

    static var pyType: PyType { get }
}

public extension PythonConvertible {
    @inlinable init?(_ reference: PyAPI.Reference?) {
        guard let value = Self.fromPython(reference) else { return nil }
        self = value
    }
    
    @inlinable func toPython(_ reference: PyAPI.Reference?) {
        guard let reference else { return }
        var copy = self
        copy.toPython(reference)
    }
    
    @inlinable static func fromPython(_ reference: PyAPI.Reference?) -> Self? {
        guard let reference, py_istype(reference, pyType) else { return nil }
        return fromPython(reference)
    }
    
    @discardableResult
    @inlinable
    static func newPythonObject(_ reference: PyAPI.Reference) -> UnsafeMutableRawPointer {
        let ud = py_newobject(reference, pyType, 0, PyAPI.pointerSize)
        ud?.storeBytes(of: nil, as: UnsafeRawPointer?.self)
        return ud!
    }
}

extension Bool: PythonConvertible {
    public static let pyType = PyType.bool
    
    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newbool(reference, self)
    }
    
    @inlinable public static func fromPython(_ reference: PyAPI.Reference) -> Bool {
        py_tobool(reference)
    }
}

extension Int: PythonConvertible {
    public static let pyType = PyType.int

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newint(reference, py_i64(self))
    }

    @inlinable public static func fromPython(_ reference: PyAPI.Reference) -> Int {
        Int(py_toint(reference))
    }
}

extension String: PythonConvertible {
    public static let pyType = PyType.str

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newstr(reference, self)
    }

    @inlinable public static func fromPython(_ reference: PyAPI.Reference) -> String {
        String(cString: py_tostr(reference))
    }
}

extension Double: PythonConvertible {
    public static let pyType = PyType.float

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newfloat(reference, self)
    }

    @inlinable public static func fromPython(_ reference: PyAPI.Reference) -> Double {
        Double(py_tofloat(reference))
    }
}

extension Array: PythonConvertible where Element: PythonConvertible {
    public static var pyType: PyType { .list }
    
    public func toPython(_ reference: PyAPI.Reference) {
        py_newlist(reference)
        let r0 = py_getreg(0)!
        for value in self {
            value.toPython(r0)
            py_list_append(reference, r0)
        }
    }

    public static func fromPython(_ reference: PyAPI.Reference) -> [Element] {
        var items: [Element] = []
        for i in 0 ..< py_list_len(reference) {
            if let item = Element.fromPython(py_list_getitem(reference, i)) {
                items.append(item)
            }
        }

        return items
    }
}
