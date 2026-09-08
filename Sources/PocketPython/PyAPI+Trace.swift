//
//  PyAPI+Trace.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-06.
//

import pocketpy

public extension PyAPI {
    /// A VM trace event, mirroring pocketpy's `py_TraceEvent`.
    enum TraceEvent: Equatable {
        /// About to execute a new source line.
        case line
        /// A frame was pushed (a call was entered).
        case push
        /// A frame was popped (a call returned or raised).
        case pop

        init(_ event: py_TraceEvent) {
            if event == TRACE_EVENT_PUSH {
                self = .push
            } else if event == TRACE_EVENT_POP {
                self = .pop
            } else {
                self = .line
            }
        }
    }

    /// A lightweight view over a pocketpy call frame passed to a trace function.
    ///
    /// The underlying pointer is only valid for the duration of the trace
    /// callback. Do not store a `Frame` beyond the call.
    struct Frame {
        public let reference: OpaquePointer

        /// The current source line being executed, or `nil` if unavailable.
        public var lineNumber: Int? {
            var line: Int32 = -1
            _ = py_Frame_sourceloc(reference, &line)
            return line >= 0 ? Int(line) : nil
        }

        /// The source location (filename) of the frame, if available.
        public var sourceLocation: String? {
            var line: Int32 = -1
            guard let cString = py_Frame_sourceloc(reference, &line) else {
                return nil
            }
            return String(cString: cString)
        }

        /// The function object running in this frame, if any.
        public var function: PyRef? {
            py_Frame_function(reference)
        }
    }

    /// A trace callback invoked by the VM as it executes Python code.
    typealias TraceFunction = @MainActor (Frame, TraceEvent) -> Void

    /// Installs a trace function invoked by the VM on every source line and on
    /// every frame push/pop, or removes the current one when `trace` is `nil`.
    ///
    /// The callback runs synchronously on the interpreter (main) thread between
    /// bytecode instructions, so it is a safe place to inspect frame state or
    /// request cooperative cancellation. Keep it fast: it fires very frequently.
    func setTrace(_ trace: TraceFunction?) {
        PyAPI.traceFunction = trace
        py_sys_settrace(trace == nil ? nil : traceTrampoline, true)
    }

    /// The currently installed Swift trace function, bridged to the C hook.
    internal static var traceFunction: TraceFunction?
}

/// C trampoline handed to `py_sys_settrace`. `py_TraceFunc` carries no user
/// context, so the Swift closure is read from ``PyAPI/traceFunction``.
@MainActor
private let traceTrampoline: py_TraceFunc = { frame, event in
    guard let frame,
          let trace = PyAPI.traceFunction else {
        return
    }
    trace(PyAPI.Frame(reference: frame), PyAPI.TraceEvent(event))
}
