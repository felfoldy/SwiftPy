//
//  View.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-06-06.
//

import SwiftUI

// `PyType.View` itself is backend vocabulary and lives in the backend module.

#if cpython

/// Releases the view an instance held. A named function: a C function pointer
/// cannot be formed from a capturing closure.
private func releaseView(_ userdata: UnsafeMutableRawPointer?) {
    userdata?.assumingMemoryBound(to: AnyView?.self).deinitialize(count: 1)
}

/// `__new__` initializes the slot rather than leaving the zeroed bytes an
/// `AnyView?` would have to be read out of.
private let allocateEmptyView: PyAPI.CFunction = { cls, _ in
    guard let cls else { return nil }
    // The pointer only crosses onto the main actor, which is where CPython
    // calls back from; it is never shared.
    nonisolated(unsafe) let type = cls
    return PyAPI.return { py.newobject(AnyView?.none, type: py.totype(type)) }
}

@MainActor
extension AnyView: @retroactive PythonConvertible {
    public static let pyType: PyType = {
        let type = py.newtype(
            name: "AnyView",
            storage: MemoryLayout<AnyView?>.size,
            dtor: releaseView
        )!
        type.function("__new__(cls, *args, **kwargs)", block: allocateEmptyView)
        return type
    }()

    public func toPython() throws(PythonError) -> PyObject {
        guard let object = py.newobject(Optional(self), type: Self.pyType) else {
            throw .SystemError("could not allocate an AnyView")
        }
        return object
    }

    public static func fromPython(_ reference: PyRef) -> AnyView {
        reference.toUserdata(as: AnyView?.self) ?? AnyView(erasing: EmptyView())
    }

    /// Only a real `AnyView`: reading a `View` subclass means calling its
    /// `body`, which is what `PyRef.view` does and is not ported yet.
    public static func isConvertible(_ reference: PyRef) -> Bool {
        pyType.isExactType(of: reference)
    }
}

#else
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
#endif
