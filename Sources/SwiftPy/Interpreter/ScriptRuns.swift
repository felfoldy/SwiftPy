//
//  ScriptRuns.swift
//  SwiftPy
//

import Synchronization

/// The run each script name last ran as, so a line of that script reports to
/// it wherever it's called from. Behind a lock: it's read from Python's thread.
enum ScriptRuns {
    private static let runs = Mutex<[String: UInt64]>([:])

    static func record(_ name: String, run id: UInt64) {
        runs.withLock { $0[name] = id }
    }

    /// The run a source belongs to; an unnamed run is called `<script>/<id>`.
    static func runId(for source: String) -> UInt64? {
        if let id = runs.withLock({ $0[source] }) { return id }
        let prefix = "<script>/"
        guard source.hasPrefix(prefix) else { return nil }
        return UInt64(source.dropFirst(prefix.count))
    }

    /// The innermost script line on the running stack, and the run it reports
    /// to; only `run`'s lines when given. pocketpy can't walk its stack, so
    /// it reads the last line `tracer` saw instead.
    static func currentLine(tracer: LineTracer?, run: UInt64? = nil) -> (run: UInt64, line: Int)? {
        func owner(_ source: String) -> UInt64? {
            guard let id = runId(for: source), run == nil || run == id else { return nil }
            return id
        }
        #if cpython
        guard let frame = PyAPI.frame(where: { owner($0) != nil }),
              let id = owner(frame.source) else { return nil }
        return (id, frame.line)
        #else
        guard let entry = tracer?.entries.last(where: { owner($0.source) != nil }),
              let id = owner(entry.source) else { return nil }
        return (id, entry.lineNumber)
        #endif
    }

    /// The last line of `run` in a formatted traceback: where it raised, or
    /// called what did.
    static func raisingLine(in traceback: String, run: UInt64) -> Int? {
        // Without the colours CPython adds around the name and the number.
        let plain = traceback.replacing(/\u{1B}\[[0-9;]*m/, with: "")
        let pattern = /File "(?<source>[^"]+)", line (?<line>\d+)/
        return plain.matches(of: pattern)
            .last { runId(for: String($0.source)) == run }
            .flatMap { Int($0.line) }
    }
}
