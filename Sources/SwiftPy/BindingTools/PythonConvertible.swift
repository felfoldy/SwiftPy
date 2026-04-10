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
    /// Returns the reference to the type object.
    @inlinable
    static var pyTypeObject: PyAPI.Reference? {
        py.tpobject(pyType)
    }

    @inlinable
    init?(_ reference: PyAPI.Reference?) {
        guard let reference else { return nil }
        let canCast = py.istype(reference, type: Self.pyType) ||
        py.isinstance(reference, type: Self.pyType)
        guard canCast else { return nil }
        self = Self.fromPython(reference)
    }
    
    @inlinable func toPython(_ reference: PyAPI.Reference?) {
        guard let reference else { return }
        toPython(reference)
    }
    
    @inlinable
    static func cast(_ arg: PyAPI.Reference?, _ offset: Int = 0) throws(PythonError) -> Self {
        guard let arg = arg?[offset] else {
            throw PythonError.TypeError("Expected \(pyType.name) at position \(offset)")
        }
        
        if arg.canCast(to: pyType) {
            return Self.fromPython(arg)
        }
        
        if arg.isNone && Self.self is ExpressibleByNilLiteral.Type {
            return Self.fromPython(arg)
        }

        throw PythonError.TypeError("Expected \(pyType.name) got \(py.typeof(arg).name) at position \(offset)")
    }
}

extension Bool: PythonConvertible {
    public static let pyType = PyType.bool
    
    @inlinable
    public func toPython(_ reference: PyAPI.Reference) {
        py.newbool(reference, value: self)
    }
    
    @inlinable
    public static func fromPython(_ reference: PyAPI.Reference) -> Bool {
        py.tobool(reference)
    }
}

extension Int: PythonConvertible {
    public static let pyType = PyType.int

    @inlinable
    public func toPython(_ reference: PyAPI.Reference) {
        py.newint(reference, value: self)
    }

    @inlinable
    public static func fromPython(_ reference: PyAPI.Reference) -> Int {
        py.toint(reference)
    }
}

extension Int64: PythonConvertible {
    public static let pyType = PyType.int

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py.newint(reference, value: Int(self))
    }

    @inlinable public static func fromPython(_ reference: PyAPI.Reference) -> Int64 {
        Int64(py.toint(reference))
    }
}

extension String: PythonConvertible {
    public static let pyType = PyType.str

    @inlinable public func toPython(_ reference: PyAPI.Reference) {
        py.newstr(reference, value: self)
    }

    @inlinable public static func fromPython(_ reference: PyAPI.Reference) -> String {
        if py.typeof(reference) == .str {
            return py.tostr(reference)
        }

        if let path = Path(reference) {
            return path.url.path
        }

        return ""
    }
}

extension Double: PythonConvertible {
    public static let pyType = PyType.float

    @inlinable
    public func toPython(_ reference: PyAPI.Reference) {
        py.newfloat(reference, value: self)
    }

    @inlinable
    public static func fromPython(_ reference: PyAPI.Reference) -> Double {
        py.castfloat(reference)
    }
}

extension Float: PythonConvertible {
    public static let pyType = PyType.float

    @inlinable
    public func toPython(_ reference: PyAPI.Reference) {
        py.newfloat(reference, value: Double(self))
    }

    @inlinable
    public static func fromPython(_ reference: PyAPI.Reference) -> Float {
        Float(py.castfloat(reference))
    }
}

extension Data: PythonConvertible {
    public static let pyType = PyType.bytes

    public func toPython(_ reference: PyAPI.Reference) {
        let count = self.count
        let bytes = py.newbytes(reference, n: count)
        copyBytes(to: bytes)
    }

    public static func fromPython(_ reference: PyAPI.Reference) -> Data {
        py.tobytes(reference)
    }
}

extension Optional: PythonConvertible where Wrapped: PythonConvertible {

    public static var pyType: PyType { Wrapped.pyType }
    
    public func toPython(_ reference: PyAPI.Reference) {
        if let wrappedValue = self {
            wrappedValue.toPython(reference)
        } else {
            py.newnone(reference)
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
        py.newlist(reference)
        for value in self {
            guard let value = value as? PythonConvertible else {
                log.error("\(value) is not convertible to Python")
                continue
            }
            py.list.append(
                reference,
                value: value.retained.reference
            )
        }
    }

    public static func fromPython(_ reference: PyAPI.Reference) -> [Element] {
        var items: [Element] = []
        
        let array = reference.retained
        
        try? array.iterate { item in
            if Element.self == Any?.self {
                items.append(item.reference?.asAny as! Element)
                return
            }
            
            guard let type = Element.self as? PythonConvertible.Type else {
                log.error("\(Element.self) is not convertible to Python")
                return
            }
            
            let item = type.init(item.reference)
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
        py.newdict(reference)
        for (key, value) in self {
            guard let value = value as? PythonConvertible else {
                log.error("\(value) is not convertible to Python")
                continue
            }
 
            let keyStack = TempPyObject(key)
            let valueStack = TempPyObject(value)
            _ = py.dict.setitem(
                reference,
                key: keyStack?.reference,
                value: valueStack?.reference
            )
        }
    }

    public static func fromPython(_ reference: PyAPI.Reference) -> [Key: Value] {
        var dict = [Key: Value]()
        
        do {
            let items = try reference.attribute("items")?.call()?.retained
            
            try items?.iterate { item in
                let keyRef = py.tuple.getitem(item.reference, i: 0)
                guard let key = Key(keyRef) else {
                    throw ConversionError.key
                }
                
                let valueRef = py.tuple.getitem(item.reference, i: 1)
                
                if let Convertible = Value.self as? PythonConvertible.Type,
                   let value = Convertible.init(valueRef) {
                    dict[key] = value as? Value
                    return
                }
                
                if Value.self == Any.self {
                    dict[key] = valueRef?.asAny as? Value
                    return
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
