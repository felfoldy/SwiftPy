//
//  ViewState.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-16.
//

#if cpython
import Observation
import SwiftUI

/// What makes a Python `View` subclass live: the box its writes bump, which
/// the SwiftUI side observes to call `body()` again.
///
/// Kept in the instance's `__dict__`, so a Swift-backed view, which has none
/// and keeps its state on the Swift side, never gets one.
@MainActor
@Observable
final class ViewState: PythonBindable {
    @ObservationIgnored var _pythonCache = PythonBindingCache()

    private(set) var revision = 0

    func invalidate() {
        revision += 1
    }

    static let pyType: PyType = .make("ViewState") { type in
        type.function("invalidate(self) -> None") { receiver, _ in
            PyAPI.return {
                try ViewState.cast(receiver).invalidate()
                return nil
            }
        }
        type.property("revision", getter: { receiver, _ in
            PyAPI.return { try ViewState.cast(receiver).revision }
        })
    }

    private static let key = "_view_state"

    /// The instance's box, made on first use.
    static func attached(to object: PyObject) -> ViewState? {
        guard let dict: PyObject = object.__dict__ else { return nil }
        if let existing: ViewState = dict[key] {
            return existing
        }
        let state = ViewState()
        dict[key] = state
        return state
    }

    /// Routes every attribute write on a `View` to its box. Set on the type,
    /// the slot updates for its subclasses too.
    static func installSetattr() {
        PyType.View.function("__setattr__(self, name: str, value: Any) -> None") { receiver, args in
            PyAPI.return {
                let arguments = PyArguments(method: receiver, args)
                guard let object = arguments[0].map(PyObject.init(retaining:)),
                      let name = arguments[1].map(PyObject.init(retaining:)),
                      let value = arguments[2].map(PyObject.init(retaining:)) else {
                    throw PythonError.TypeError("__setattr__ takes an object, a name and a value")
                }
                // `object` itself, looked up as an attribute: `.object` on a
                // throwing view is the box it wraps.
                let base: PyObject = try py.module("builtins")!.throwing[dynamicMember: "object"]
                try base.throwing.__setattr__(object, name, value)
                let dict: PyObject? = object.__dict__
                if let state: ViewState = dict?[ViewState.key] {
                    state.invalidate()
                }
                return nil
            }
        }
    }
}

/// Shows what a Python view's `body()` returns, and calls it again whenever
/// the view's state changes.
struct PythonView: View {
    let object: PyObject
    let state: ViewState
    @State private var rendered: AnyView

    init(object: PyObject, state: ViewState, initial: AnyView) {
        self.object = object
        self.state = state
        _rendered = State(initialValue: initial)
    }

    var body: some View {
        rendered
            .onChange(of: state.revision) {
                // A failing body keeps the last view up and reports the error.
                if let view = object.reference.bodyView {
                    rendered = view
                }
            }
    }
}
#endif
