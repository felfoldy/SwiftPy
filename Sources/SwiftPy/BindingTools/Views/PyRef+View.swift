//
//  PyRef+View.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import SwiftUI

@MainActor
public extension PyRef {
    /// Returns an `AnyView` if the object is a view.
    ///
    /// Written per backend rather than through shared primitives: `getattr`
    /// hands back a borrowed reference under pocketpy and an owned one under
    /// CPython, and only the owning side may drop it.
    var view: AnyView? {
#if cpython
        if AnyView.pyType.isExactType(of: self) {
            return AnyView.fromPython(self)
        }

        guard PyType.View.isInstance(self), let body = bodyView else {
            return nil
        }
        // A Python subclass keeps state of its own, so its body is called
        // again when that changes; a Swift-backed view is rendered once.
        guard let state = ViewState.attached(to: PyObject(retaining: self)) else {
            return body
        }
        return AnyView(PythonView(object: PyObject(retaining: self), state: state, initial: body))
#else
        // Try AnyView. AnyView cannot be subclassed.
        if py.typeof(self) == AnyView.pyType,
           let view = AnyView(self) {
            return view
        }

        // Try View.
        if py.isinstance(self, type: .View),
           let body = try? py.getattr(self, name: "body") {
            let view = try? py.call(body)
            return view?.view
        }

        return nil
#endif
    }

#if cpython
    /// What the view's `body()` produces, or nil, with the error reported,
    /// when it raises.
    internal var bodyView: AnyView? {
        let object = PyObject(retaining: self)
        do {
            return try object.throwing.body().object.reference.view
        } catch {
            Interpreter.shared.report(error)
            return nil
        }
    }
#endif

    /// The view a host presents for this object: its own, or a markdown block
    /// holding the pretty printed JSON of a dict or list.
    var displayView: AnyView? {
        if let view { return view }

        guard let source = jsonMarkdown else { return nil }
        let markdown: PyObject? = try? py.module("views")?.Markdown?(source)
        return markdown?.reference.view
    }

    /// A dict or list as a markdown json block, or nil for anything else and
    /// for a value `json.dumps` refuses.
    internal var jsonMarkdown: String? {
#if cpython
        guard PyType.dict.isExactType(of: self) || PyType.list.isExactType(of: self) else {
            return nil
        }
#else
        guard py.istype(self, type: .dict) || py.istype(self, type: .list) else {
            return nil
        }
#endif

        // Dumped through Python so the keys keep the order they were inserted in.
#if cpython
        let boxed = PyObject(retaining: self)
        guard let pretty: String = try? py.module("interpreter")?._json_markdown?(boxed) else {
            return nil
        }
#else
        let boxed = PyObject(self)
        guard let pretty: String = try? py.module("json")?.dumps?(boxed, 2) else {
            return nil
        }
#endif

        return "```json\n\(pretty)\n```"
    }
}
