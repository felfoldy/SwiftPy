//
//  LineTracer.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 08. 07..
//

import Synchronization

/// Records the lines an execution runs through. The trace arrives on whichever
/// thread runs the code, so the entries sit behind a lock.
public final class LineTracer: Sendable {
    public struct Entry: Equatable, Sendable {
        public let source: String
        public let lineNumber: Int
        public let time: Duration

        public var contextId: UInt64? {
            let prefix = "<script>/"
            guard source.hasPrefix(prefix) else { return nil }
            return UInt64(source.dropFirst(prefix.count))
        }
    }

    private let clock = ContinuousClock()
    private let startInstant: ContinuousClock.Instant
    private let storage = Mutex<[Entry]>([])

    public var entries: [Entry] {
        storage.withLock { $0 }
    }

    public init() {
        startInstant = clock.now
    }

    /// The last line executed in the given context, e.g. where an error was raised.
    public func lastLine(forContext id: UInt64) -> Int? {
        entries.last { $0.contextId == id }?.lineNumber
    }

    func record(_ frame: PyAPI.Frame, _ event: PyAPI.TraceEvent) {
        guard event == .line,
              let source = frame.sourceLocation,
              let lineNumber = frame.lineNumber
        else { return }

        let entry = Entry(
            source: source,
            lineNumber: lineNumber,
            time: startInstant.duration(to: clock.now)
        )
        storage.withLock { $0.append(entry) }
    }
}

public extension Interpreter {
    /// Enables line tracing for the active interpreter backend.
    static func enableTrace() {
        py.setTrace { frame, event in
            InterpreterExecutionContext.current.traceRecorder?.record(frame, event)
        }
    }

    static func disableTrace() {
        py.setTrace(nil)
    }
}
