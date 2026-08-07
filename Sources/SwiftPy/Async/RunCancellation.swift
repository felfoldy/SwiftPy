//
//  RunCancellation.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-08.
//

import Foundation

/// Shared cancellation token for a single execution.
///
/// The awaited work of one run spreads across a tree of unstructured
/// ``AsyncTask`` instances, so parent cancellation does not propagate on its
/// own. Each piece of awaited work registers an ``onCancel(_:)`` handler that
/// tears itself down, letting a stop request cancel the whole tree at once.
///
/// Handlers accumulate: concurrent work (e.g. `asyncio.gather`) awaits several
/// tasks at the same time, and every one of them must be cancelled.
///
/// Isolated to the main actor — the same actor ``AsyncTask`` runs on — so no
/// extra locking is needed. ``init()`` is `nonisolated` so the interpreter
/// connection actor can create the token before handing it to a run.
@MainActor
final class RunCancellation {
    private var handlers: [() -> Void] = []
    private(set) var isCancelled = false

    nonisolated init() {}

    /// Registers work to tear down when the run is stopped. A handler that
    /// registers after cancellation runs immediately.
    func onCancel(_ handler: @escaping () -> Void) {
        guard !isCancelled else {
            handler()
            return
        }
        handlers.append(handler)
    }

    /// Marks the run as cancelled and runs every registered handler.
    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true

        let pending = handlers
        handlers.removeAll()
        for handler in pending { handler() }
    }
}
