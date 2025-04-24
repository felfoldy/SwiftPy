//
//  PythonConvertible.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import pocketpy
import Foundation

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

// MARK: - Array conversion

extension Array: PythonConvertible {
    public static var pyType: PyType { .list }
    
    public func toPython(_ reference: PyAPI.Reference) {
        py_newlist(reference)
        for value in self {
            guard let value = value as? PythonConvertible else {
                log.error("\(value) is not convertible to Python")
                continue
            }
            py_list_append(reference, value.toStack.reference)
        }
    }

    public static func fromPython(_ reference: PyAPI.Reference) -> [Element] {
        var items: [Element] = []
        for i in 0 ..< py_list_len(reference) {
            if Element.self == Any?.self {
                let any = py_list_getitem(reference, i).asAny
                items.append(any as! Element)
                continue
            }
            
            guard let type = Element.self as? PythonConvertible.Type else {
                log.error("\(Element.self) is not convertible to Python")
                continue
            }
            let itemRef = py_list_getitem(reference, i)
            let item = type.fromPython(itemRef)
            if let item = item as? Element {
                items.append(item)
            }
        }

        return items
    }
}

// MARK: - Dictionary conversion

extension Dictionary: PythonConvertible where Key: PythonConvertible {
    public enum ConversionError: LocalizedError {
        case key
        case value
    }
    
    public static var pyType: PyType { .dict }

    public func toPython(_ reference: PyAPI.Reference) {
        py_newdict(reference)
        for (key, value) in self {
            guard let value = value as? PythonConvertible else {
                log.error("\(value) is not convertible to Python")
                continue
            }
 
            let keyStack = key.toStack
            let valueStack = value.toStack

            py_dict_setitem(reference, keyStack.reference, valueStack.reference)
        }
    }

    public static func fromPython(_ reference: PyAPI.Reference) -> [Key: Value] {
        var dict = [Key: Value]()
        
        do {
            let itemsStack = try PyAPI.call(reference, "items")?.toStack

            py_iter(itemsStack?.reference)
            
            let iterable = PyAPI.returnValue.toStack

            var found = false
            while true {
                found = try Interpreter.printItemError {
                    py_next(iterable.reference)
                }
                guard found else { break }

                let tupleStack = PyAPI.returnValue.toStack
                let keyRef = py_tuple_getitem(tupleStack.reference, 0)
                let valueRef = py_tuple_getitem(tupleStack.reference, 1)
                
                guard let key = Key(keyRef) else {
                    throw ConversionError.key
                }
                
                if let Convertible = Value.self as? PythonConvertible.Type,
                   let value = Convertible.init(valueRef) {
                    dict[key] = value as? Value
                    continue
                }
                
                if Value.self == Any.self {
                    dict[key] = valueRef?.asAny as? Value
                    continue
                }
                
                throw ConversionError.value
            }
        } catch {
            log.error(error.localizedDescription)
        }
        return dict
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

// MARK: - PyAPI.Reference -> Any?

@MainActor
public extension PyAPI.Reference {
    var asAny: Any? {
        if let string = String(self) { return string }
        if let int = Int(self) { return int }
        if let float = Double(self) { return float }
        if let bool = Bool(self) { return bool }
        if let array = [Any?](self) { return array }
        if let object = [String: Any](self) { return object }
        return nil
    }
}
