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
        ]

        PyBridge.stringConversions = [
            Path.pyType: { Path($0)?.url.path ?? "" }
        ]

        #if cpython
        // A binding called on the Python actor runs on main, across a hop
        // that carries no task-locals: the execution's output sink and the
        // current task are picked up here and put back around the body.
        PyBridge.carryContext = {
            let context = InterpreterExecutionContext.current
            let task = AsyncTask.current
            return { body in
                InterpreterExecutionContext.$current.withValue(context) {
                    AsyncTask.$current.withValue(task) { body() }
                }
            }
        }
        #endif

        // View casting and boxing are not ported to CPython yet; see the migration notes.
        #if !cpython
        PyBridge.implicitCasts[AnyView.pyType] = [.View]

        PyBridge.box = { value, reference in
            SwiftObject(value).toPython(reference)
        }
        #endif
    }
}
