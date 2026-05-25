//
//  PyArguments.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-25.
//

@available(*, deprecated, message: "Use PyObject for arguments")
@MainActor
public struct PyArguments {
    public let count: Int32
    public let value: PyRef?

    public init(argc: Int32, argv: PyRef?) {
        self.count = argc
        self.value = argv
    }
    
    @inlinable
    public subscript(_ offset: Int) -> PyRef? {
        value?[offset]
    }
    
    @inlinable
    public subscript(_ slot: any RawRepresentable<Int32>) -> PyRef? {
        get { value?[slot: slot.rawValue] }
        nonmutating set { value?[slot: slot.rawValue] = newValue }
    }
    
    public func expectedArgCount(_ count: Int) throws {
        try PyBind.checkArgCount(self.count, expected: count)
    }
    
    @inlinable
    public func cast<Result: PythonConvertible>(_ offset: Int32) throws(PythonError) -> Result {
        try .cast(value, Int(offset))
    }
}
