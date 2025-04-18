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
    /// Returns the stored python object for the given slot.
    ///
    /// - Note: Uses register 0.
    @inlinable
    subscript(slot: Slot) -> PyAPI.Reference? {
        get {
            withTemp { obj in
                obj[slot: slot.rawValue]
            }
        }
        set {
            toRegister(0)?[slot: slot.rawValue] = newValue
        }
    }
    
    @inlinable
    subscript<T: PythonConvertible>(slot: Slot) -> T? {
        get {
            T(self[slot])
        }
        set {
            self[slot] = newValue?.toRegister(1)
        }
    }
    
    @inlinable
    static func _bind_slot<T: PythonConvertible>(_ slot: Slot, _ argv: PyAPI.Reference?, makeBinding: (Self) -> T?) -> Bool {
        if let result = argv?[slot: slot.rawValue] {
            PyAPI.returnValue.assign(result)
            return true
        }

        guard let binding = Self(argv) else {
            return .throwTypeError(argv, 0)
        }

        makeBinding(binding)?.toPython(PyAPI.returnValue)
        argv?[slot: slot.rawValue] = PyAPI.returnValue
        return true
    }
}
