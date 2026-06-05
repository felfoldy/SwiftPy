//
//  PyTuple.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-06-05.
//

import pocketpy

public struct PyTuple: PythonConvertible {
    public var values: [PyObject]
    
    public static let pyType = PyType.tuptle
    
    public static func fromPython(_ reference: PyRef) -> PyTuple {
        let len = py.tuple.len(reference)
        var items: [PyObject?] = []
        for i in 0..<len {
            let item = py.retain(py.tuple.getitem(reference, i: i))
            items.append(item)
        }
        return PyTuple(values: items.compactMap { $0 })
    }
    
    public func toPython(_ reference: PyRef) {
        let count = values.count
        py_newtuple(reference, Int32(count))

        for i in 0..<count {
            py_tuple_setitem(reference, Int32(i), values[i].reference)
        }
    }
}

public extension PythonValueBindable {
    typealias Unpack = PyTuple
}
