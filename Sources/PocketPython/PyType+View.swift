//
//  PyType+View.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-06-06.
//

@MainActor
public extension PyType {
    /// The base a Python class subclasses to become presentable. It carries no
    /// value of its own; a subclass supplies `body`.
    static let View: PyType = {
        let type = py.newtype(
            name: "View",
            base: .object,
            module: nil,
            dtor: { _ in }
        )
        type.function("__new__(cls, *args, **kwargs)") { _, argv in
            let type = py.totype(argv)
            py.newobject(py.retval, type: type, slots: 0)
            return true
        }
        type.function("body(self) -> View") { _, _ in
            PyAPI.return {
                throw PythonError.NotImplementedError("def body(self) is not implemented")
            }
        }
        return type
    }()
}
