//
//  LineSampler.swift
//  SwiftPy
//

import Synchronization

/// Tells a run which of its lines is going, a few times a second, from a Python
/// thread of its own (`_sample_lines`). Unlike tracing, it costs a run nothing.
/// It reads a stack with the GIL, so native code holding it delays a sample.
enum LineSampler {
    private struct State {
        /// What's being sampled, as a script can run after its card has finished.
        var users = 0
        /// The last line sent for each run.
        var lines: [UInt64: Int] = [:]
    }

    private static let state = Mutex(State())

    static var isActive: Bool {
        state.withLock { $0.users > 0 }
    }

    static func begin() {
        state.withLock { $0.users += 1 }
    }

    static func end() {
        state.withLock {
            $0.users -= 1
            if $0.users == 0 { $0.lines = [:] }
        }
    }

    /// The line a script is on, sent once per change.
    @MainActor
    static func sampled(source: String, line: Int) {
        guard let id = ScriptRuns.runId(for: source) else { return }
        let isNew = state.withLock { state -> Bool in
            guard state.lines[id] != line else { return false }
            state.lines[id] = line
            return true
        }
        guard isNew else { return }
        Interpreter.shared.connection.send(
            id: id,
            .feedback(item: ExecutionFeedback(lineNumber: line, type: .running))
        )
    }
}

public extension Interpreter {
    /// Whether anything is having its lines sampled.
    nonisolated static var isSamplingLines: Bool { LineSampler.isActive }

    /// Samples what runs outside a card's run, such as a coroutine a button
    /// started, until a matching ``endLineSampling()``.
    @MainActor
    static func beginLineSampling() {
        LineSampler.begin()
        #if cpython
        _ = try? py.module("interpreter")?._start_line_sampler?()
        #endif
    }

    nonisolated static func endLineSampling() {
        LineSampler.end()
    }
}
