//
//  HasSlots.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-15.
//

import pocketpy

@MainActor
public protocol HasSlots<Slot> {
    associatedtype Slot: RawRepresentable<Int32>, CaseIterable
}

public extension HasSlots {
    static var slotCount: Int { Slot.allCases.count }
}

public extension PythonBindable where Self: HasSlots {
    @inlinable
    subscript(slot: Slot) -> PyAPI.Reference? {
        get {
            guard let result = py_getslot(toRegister(0), slot.rawValue),
                  !result.isNil else {
                return nil
            }
            return result
        }
        set {
            py_setslot(toRegister(0), slot.rawValue, newValue)
        }
    }
    
    @inlinable
    subscript<T: PythonConvertible>(slot: Slot) -> T? {
        get {
            guard let result = py_getslot(toRegister(0), slot.rawValue),
                  !result.isNil else {
                return nil
            }
            return T(result)
        }
        set {
            py_setslot(toRegister(0), slot.rawValue, newValue?.toRegister(1))
        }
    }
    
    @inlinable
    static func _bind_slot<T: PythonConvertible>(_ slot: Slot, _ argv: PyAPI.Reference?, makeBinding: (Self) -> T?) -> Bool {
        guard let obj = Self(argv) else {
            return .throwTypeError(argv, 0)
        }
        
        if let cached = obj[slot] {
            PyAPI.returnValue.assign(cached)
            return true
        }
        
        let binding = makeBinding(obj)
        obj[slot] = binding
        return PyAPI.return(binding)
    }
}
