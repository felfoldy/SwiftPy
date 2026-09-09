// Not ported to CPython yet; see the migration notes.
#if !cpython
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
    @inlinable
    var view: AnyView? {
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
    }

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
        guard py.istype(self, type: .dict) || py.istype(self, type: .list) else {
            return nil
        }

        // Dumped through Python so the keys keep the order they were inserted in.
        guard let pretty: String = try? py.module("json")?.dumps?(PyObject(self), 2) else {
            return nil
        }

        return "```json\n\(pretty)\n```"
    }
}

#endif
