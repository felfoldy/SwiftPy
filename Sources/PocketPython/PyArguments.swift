//
//  PyArguments.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import pocketpy

/// The pair of values a C binding is handed, behind one name.
///
/// The pair is the backend's: pocketpy passes `(argc, argv)`, CPython
/// `(self, args)`. Binding code that is meant to be shared names their types
/// through ``RawFirst`` and ``RawSecond`` and never reads them directly, so the
/// same source compiles against either.
@MainActor
public struct PyArguments {
    public typealias RawFirst = Int32
    public typealias RawSecond = PyRef?

    @usableFromInline let argc: Int32
    @usableFromInline let argv: PyRef?

    @inlinable
    public init(_ first: RawFirst, _ second: RawSecond) {
        argc = first
        argv = second
    }

    @inlinable
    public var count: Int { Int(argc) }

    /// The argument at `index`, or nil past the end.
    @inlinable
    public subscript(index: Int) -> PyRef? {
        guard index >= 0, index < count else { return nil }
        return argv?[index]
    }
}

/// What a binding answers with. pocketpy reports success, CPython returns the
/// result itself.
public typealias PyReturn = Bool
