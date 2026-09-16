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

    /// Routes every attribute write on a `View` to its box. Assigned from
    /// Python so that the slot updates for the subclasses too.
    static func installSetattr() {
        let source = """
        def _view_setattr(self, name, value):
            object.__setattr__(self, name, value)
            state = getattr(self, '__dict__', {}).get('_view_state')
            if state is not None:
                state.invalidate()
        View.__setattr__ = _view_setattr
        """
        do {
            let namespace = try PyObject.newDict()
            try Interpreter.execute(try Interpreter.compile(source), globals: namespace)
        } catch {
            log.error("Could not install View.__setattr__: \(error)")
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
