//
//  TypeConversions.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import pocketpy

@MainActor
public protocol ConvertibleFromPython {
    @inlinable init?(_ reference: PyAPI.Reference?)
}

extension Bool: ConvertibleFromPython {
    public init?(_ reference: PyAPI.Reference?) {
        guard let reference, reference.isType(.bool) else {
            return nil
        }

        self = py_tobool(reference)
    }
}

extension Int: ConvertibleFromPython {
    public init?(_ reference: PyAPI.Reference?) {
        guard let reference, reference.isType(.int) else {
            return nil
        }

        self = Int(py_toint(reference))
    }
}

extension String: ConvertibleFromPython {
    public init?(_ reference: PyAPI.Reference?) {
        guard let reference, reference.isType(.str) else {
            return nil
        }

        self = String(cString: py_tostr(reference))
    }
}

extension Double: ConvertibleFromPython {
    public init?(_ reference: PyAPI.Reference?) {
        guard let reference, reference.isType(.float) else {
            return nil
        }

        self = Double(py_tofloat(reference))
    }
}
