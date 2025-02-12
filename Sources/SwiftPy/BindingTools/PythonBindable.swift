//
//  PythonBindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import pocketpy

public protocol PythonBindable: AnyObject, PythonConvertible {
    var _cachedPythonReference: PyAPI.Reference? { get set }
}

public extension PythonBindable {
    @inlinable static func deinitFromPython(_ userdata: UnsafeMutableRawPointer?) {
        guard let pointer = userdata?.load(as: UnsafeRawPointer?.self) else {
            return
        }

        // Tale retained value.
        let unmanaged = Unmanaged<Self>.fromOpaque(pointer)
        let obj = unmanaged.takeRetainedValue()

        // Clear cache.
        UnsafeRawPointer(obj._cachedPythonReference)?.deallocate()
        obj._cachedPythonReference = nil
    }
    
    @inlinable
    func storeInPython(_ reference: PyAPI.Reference?, userdata: UnsafeMutableRawPointer?) {
        // Store retained self pointer in python userdata.
        let retainedSelfPointer = Unmanaged.passRetained(self)
            .toOpaque()
        userdata?.storeBytes(of: retainedSelfPointer,
                             as: UnsafeRawPointer.self)
        
        // Store cache of python object.
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: 16, alignment: 8)
        let opaquePointer = OpaquePointer(pointer)
        py_assign(opaquePointer, reference)
        _cachedPythonReference = opaquePointer
    }
    
    @inlinable
    func toPython(_ reference: PyAPI.Reference) {
        if let _cachedPythonReference {
            py_assign(reference, _cachedPythonReference)
            return
        }
        
        let userdata = Self.newPythonObject(reference)
        storeInPython(reference, userdata: userdata)
    }
    
    @inlinable
    static func fromPython(_ reference: PyAPI.Reference) -> Self {
        let pointer = py_touserdata(reference)
            .load(as: UnsafeRawPointer.self)
        return Unmanaged<Self>.fromOpaque(pointer)
            .takeUnretainedValue()
    }
}
