//
//  View.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-06-06.
//

import SwiftUI

@MainActor
public extension PyType {
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
        type.function("body(self) -> View") { argc, argv in
            PyAPI.return {
                throw PythonError.NotImplementedError("def body(self) is not implemented")
            }
        }
        return type
    }()
}

extension AnyView: PythonConvertible {
    public func toPython(_ reference: PyRef) {
        py.newobject(self, type: Self.pyType, out: reference, slots: 0)
    }

    public static func fromPython(_ reference: PyRef) -> AnyView {
        if py.typeof(reference) == pyType {
            reference.toUserdata()
        } else {
            reference.view ?? AnyView(erasing: EmptyView())
        }
    }

    public static let pyType = py.newtype(
        name: "AnyView",
        base: .object,
        module: py.getmodule("__main__")
    ) { pointer in
        deinitialize(userdata: pointer)
    }
}
