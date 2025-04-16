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

extension PythonBindable where Self: HasSlots {
    public subscript(slot: Slot) -> PyAPI.Reference? {
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
    
    public subscript<T: PythonConvertible>(slot: Slot) -> T? {
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
}
