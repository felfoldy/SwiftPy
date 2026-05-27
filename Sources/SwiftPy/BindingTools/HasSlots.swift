//
//  HasSlots.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-15.
//

@available(*, deprecated, message: "Use PyObject instead.")
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
    subscript(slot: Slot) -> PyRef? {
        get {
            let obj = py.retain(self)
            return obj?.reference[slot: slot.rawValue]
        }
        set {
            let temp = py.retain(self)
            temp?.reference[slot: slot.rawValue] = newValue
        }
    }
    
    @inlinable
    subscript<T: PythonConvertible>(slot: Slot) -> T? {
        get { T(self[slot]) }
        set {
            let tempValue = py.retain(newValue)
            self[slot] = tempValue?.reference
        }
    }
}
