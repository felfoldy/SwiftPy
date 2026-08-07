//
//  LineTracer.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 08. 07..
//

@MainActor
public final class LineTracer {
    public struct Entry: Equatable {
        public let source: String
        public let lineNumber: Int
        public let time: Duration
    }

    private let clock = ContinuousClock()
    private let startInstant: ContinuousClock.Instant
    public private(set) var entries: [Entry] = []

    public init() {
        startInstant = clock.now
    }

    func record(_ frame: PyAPI.Frame, _ event: PyAPI.TraceEvent) {
        guard event == .line,
              let source = frame.sourceLocation,
              let lineNumber = frame.lineNumber
        else { return }

        entries.append(Entry(
            source: source,
            lineNumber: lineNumber,
            time: startInstant.duration(to: clock.now)
        ))
    }
}

public extension Interpreter {
    static func enableTrace() {
        py.setTrace { frame, event in
            InterpreterExecutionContext.current.traceRecorder?.record(frame, event)
        }
    }

    static func disableTrace() {
        py.setTrace(nil)
    }
}
