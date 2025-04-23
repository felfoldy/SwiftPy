//
//  PythonConvertible.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import pocketpy

@MainActor
public protocol PythonConvertible {
    @inlinable func toPython(_ reference: PyAPI.Reference)
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
        toPython(reference)
    }
    
    /// Writes a `PythonObject` to a register at the specific index.
    /// - Parameter index: index
    /// - Returns: Reference to the register.
    @inlinable func toRegister(_ index: Int32) -> PyAPI.Reference? {
        let register = py_getreg(index)
        toPython(register)
        return register
    }
    
    // TODO: Because it returns nil if the type is not matching when Self is optional it can override the value.
    // Consider throwing an error instead of optional?
    @inlinable static func fromPython(_ reference: PyAPI.Reference?) -> Self? {
        guard let reference else { return nil }
        guard py_istype(reference, pyType) || py_isinstance(reference, pyType) else {
            return nil
        }
        return fromPython(reference)
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

extension Float: PythonConvertible {
    public static let pyType = PyType.float

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py_newfloat(reference, Double(self))
    }

    @inlinable public static func fromPython(_ reference: PyAPI.Reference) -> Float {
        Float(py_tofloat(reference))
    }
}

extension Optional: PythonConvertible where Wrapped: PythonConvertible {

    public static var pyType: PyType { .object }
    
    public func toPython(_ reference: PyAPI.Reference) {
        if let wrappedValue = self {
            wrappedValue.toPython(reference)
        } else {
            py_newnone(reference)
        }
    }

    public static func fromPython(_ reference: PyAPI.Reference) -> Optional<Wrapped> {
        Wrapped(reference)
    }
}

extension Array: PythonConvertible where Element: PythonConvertible {
    public static var pyType: PyType { .list }
    
    public func toPython(_ reference: PyAPI.Reference) {
        py_newlist(reference)
        for value in self {
            py_list_append(reference, value.toRegister(0))
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

extension PyAPI.Reference: PythonConvertible {
    public static let pyType = PyType.object
    
    @inlinable
    public func toPython(_ reference: PyAPI.Reference) {
        reference.assign(self)
    }

    @inlinable
    public static func fromPython(_ reference: PyAPI.Reference) -> PyAPI.Reference {
        reference
    }
}
