//
//  View.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-06-06.
//

import SwiftUI

// `PyType.View` itself is backend vocabulary and lives in the backend module.

@MainActor
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
