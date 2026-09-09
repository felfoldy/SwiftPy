// Not ported to CPython yet; see the migration notes.
#if !cpython
//
//  PyBridge+SwiftPy.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import SwiftUI

extension Interpreter {
    /// Teaches the low-level layer the conversions only SwiftPy knows about.
    /// Runs after the bindings, so the types it names already exist.
    func registerBridge() {
        PyBridge.implicitCasts = [
            .str: [Path.pyType],
            AnyView.pyType: [.View],
        ]

        PyBridge.stringConversions = [
            Path.pyType: { Path($0)?.url.path ?? "" }
        ]

        PyBridge.box = { value, reference in
            SwiftObject(value).toPython(reference)
        }
    }
}

#endif
