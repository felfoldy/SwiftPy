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
    @inlinable func toPython(_ reference: PyRef)
    @inlinable static func fromPython(_ reference: PyRef) -> Self

    static var pyType: PyType { get }
}

public extension PythonConvertible {
    /// Returns the reference to the type object.
    @inlinable
    static var pyTypeObject: PyRef? {
        py.tpobject(pyType)
    }
    
    @inlinable
    static func deinitialize(userdata: UnsafeMutableRawPointer?) {
        userdata?
            .assumingMemoryBound(to: Self.self)
            .deinitialize(count: 1)
    }

    @inlinable
    init?<Reference: PyReferencing>(_ value: Reference?) {
        guard let reference = value?.reference else { return nil }
        let canCast = py.istype(reference, type: Self.pyType) ||
        py.isinstance(reference, type: Self.pyType)
        guard canCast else { return nil }
        self = Self.fromPython(reference)
    }
    
    @inlinable func toPython(_ reference: PyRef?) {
        guard let reference else { return }
        toPython(reference)
    }
    
    @inlinable
    static func cast(_ arg: PyRef?, _ offset: Int = 0) throws(PythonError) -> Self {
        guard let arg = arg?[offset] else {
            throw .TypeError("Expected \(pyType.name) at position \(offset)")
        }
        
        if arg.canCast(to: pyType) {
            return Self.fromPython(arg)
        }
        
        if arg.isNone && Self.self is ExpressibleByNilLiteral.Type {
            return Self.fromPython(arg)
        }

        throw .TypeError("Expected \(pyType.name) got \(py.typeof(arg).name) at position \(offset)")
    }
}

extension Bool: PythonConvertible {
    public static let pyType = PyType.bool
    
    @inlinable
    public func toPython(_ reference: PyRef) {
        py.newbool(reference, value: self)
    }
    
    @inlinable
    public static func fromPython(_ reference: PyRef) -> Bool {
        py.tobool(reference)
    }
}

extension Int: PythonConvertible {
    public static let pyType = PyType.int

    @inlinable
    public func toPython(_ reference: PyRef) {
        py.newint(reference, value: self)
    }

    @inlinable
    public static func fromPython(_ reference: PyRef) -> Int {
        py.toint(reference)
    }
}

extension Int64: PythonConvertible {
    public static let pyType = PyType.int

    @inlinable public func toPython(_ reference: PyRef) {
        py.newint(reference, value: Int(self))
    }

    @inlinable public static func fromPython(_ reference: PyRef) -> Int64 {
        Int64(py.toint(reference))
    }
}

extension String: PythonConvertible {
    public static let pyType = PyType.str

    @inlinable public func toPython(_ reference: PyRef) {
        py.newstr(reference, value: self)
    }

    @inlinable public static func fromPython(_ reference: PyRef) -> String {
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
    public func toPython(_ reference: PyRef) {
        py.newfloat(reference, value: self)
    }

    @inlinable
    public static func fromPython(_ reference: PyRef) -> Double {
        py.castfloat(reference)
    }
}

extension Float: PythonConvertible {
    public static let pyType = PyType.float

    @inlinable
    public func toPython(_ reference: PyRef) {
        py.newfloat(reference, value: Double(self))
    }

    @inlinable
    public static func fromPython(_ reference: PyRef) -> Float {
        Float(py.castfloat(reference))
    }
}

extension Data: PythonConvertible {
    public static let pyType = PyType.bytes

    public func toPython(_ reference: PyRef) {
        let count = self.count
        let bytes = py.newbytes(reference, n: count)
        copyBytes(to: bytes)
    }

    public static func fromPython(_ reference: PyRef) -> Data {
        py.tobytes(reference)
    }
}

extension Optional: PythonConvertible where Wrapped: PythonConvertible {

    public static var pyType: PyType { Wrapped.pyType }
    
    public func toPython(_ reference: PyRef) {
        if let wrappedValue = self {
            wrappedValue.toPython(reference)
        } else {
            py.newnone(reference)
        }
    }

    public static func fromPython(_ reference: PyRef) -> Optional<Wrapped> {
        Wrapped(reference)
    }
}

// MARK: - Array conversion

extension Array: PythonConvertible {
    public static var pyType: PyType { .list }
    
    public func toPython(_ reference: PyRef) {
        py.newlist(reference)
        for value in self {
            guard let value = value as? PythonConvertible else {
                log.error("\(String(describing: value)) is not convertible to Python")
                continue
            }
            let tmp = py.pushtmp()
            defer { py.pop() }
            value.toPython(tmp)
            py.list.append(
                reference,
                value: tmp
            )
        }
    }

    public static func fromPython(_ reference: PyRef) -> [Element] {
        var items: [Element] = []
        
        guard let iter = try? py.retain(py.iter(reference)) else {
            return items
        }
        
        while let item = try? py.next(iter.reference) {
            if Element.self == Any?.self {
                items.append(item.asAny as! Element)
                continue
            }
            
            guard let type = Element.self as? PythonConvertible.Type else {
                log.error("\(Element.self) is not convertible to Python")
                continue
            }
            
            let item = type.init(item)
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

    public func toPython(_ reference: PyRef) {
        py.newdict(reference)
        for (key, value) in self {
            guard let value = value as? PythonConvertible else {
                log.error("\(String(describing: value)) is not convertible to Python")
                continue
            }
 
            let keyStack = py.retain(key)
            let valueStack = py.retain(value)
            _ = try? py.dict.setitem(
                reference,
                key: keyStack?.reference,
                value: valueStack?.reference
            )
        }
    }

    public static func fromPython(_ reference: PyRef) -> [Key: Value] {
        var dict = [Key: Value]()
        
        do {
            let strong = py.retain(reference)
            guard let items: PyObject = try strong.items?() else {
                return dict
            }

            let iter = try py.retain(py.iter(items.reference))
            
            while let item = try? py.next(iter.reference) {
                let keyRef = py.tuple.getitem(item, i: 0)
                guard let key = Key(keyRef) else {
                    throw ConversionError.key
                }
                
                let valueRef = py.tuple.getitem(item, i: 1)
                
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
            log.error("\(error.localizedDescription)")
        }
        return dict
    }
}

extension PyRef: PythonConvertible {
    public static let pyType = PyType.object
    
    @inlinable
    public func toPython(_ reference: PyRef) {
        reference.assign(self)
    }

    public static func fromPython(_ reference: PyRef) -> PyRef {
        #if DEBUG
        assertionFailure("Casting PyRef is unsafe. Use PyObject instead.")
        #endif
        return reference
    }
}

// MARK: - PyRef -> Any?

@MainActor
public extension PyRef {
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
