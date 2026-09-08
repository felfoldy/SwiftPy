//
//  PythonBindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

// Only the declarations live here; the default implementations need `AsyncTask`
// and `SwiftObject`, so they stay in SwiftPy.
public protocol PythonValueBindable: PythonConvertible {}

@MainActor
public protocol PythonBindable: AnyObject, PythonValueBindable {
    var _pythonCache: PythonBindingCache { get set }
}

public struct PythonBindingCache {
    public var reference: PyRef?
    public init() {}
}
