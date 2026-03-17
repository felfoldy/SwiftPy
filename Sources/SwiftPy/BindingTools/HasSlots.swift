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
    @inlinable
    subscript(slot: Slot) -> PyAPI.Reference? {
        get {
            let temp = self.retained
            return temp.reference?[slot: slot.rawValue]
        }
        set {
            let temp = self.retained
            temp.reference?[slot: slot.rawValue] = newValue
        }
    }
    
    @inlinable
    subscript<T: PythonConvertible>(slot: Slot) -> T? {
        get { T(self[slot]) }
        set {
            let tempValue = newValue?.retained
            self[slot] = tempValue?.reference
        }
    }
}
