//
//  HasSubscript.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-02.
//

import pocketpy

@MainActor
public protocol HasSubscript<Key, Value>: PythonBindable {
    associatedtype Key: PythonConvertible
    associatedtype Value: PythonConvertible

    subscript(key: Key) -> Value { get }
}

public extension HasSubscript {
    @inlinable
    func __getitem__(_ key: Key) -> Value {
        self[key]
    }
}
