//
//  StoppableCalls.swift
//  SwiftPy
//

#if cpython
/// The cell's side of `interpreter.stoppable`: it waits here, where a stop
/// ends the wait, while a worker thread makes the call and finishes the token.
@MainActor
enum StoppableCalls {
    private static var waiting: [Int: CheckedContinuation<Void, Never>] = [:]
    // Finished before the cell waited, or after a stop gave up on it.
    private static var finished: Set<Int> = []
    private static var abandoned: Set<Int> = []

    static func finish(_ token: Int) {
        if abandoned.remove(token) != nil { return }
        if let continuation = waiting.removeValue(forKey: token) {
            continuation.resume()
        } else {
            finished.insert(token)
        }
    }

    static func wait(_ token: Int) async throws {
        if finished.remove(token) != nil { return }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    abandoned.insert(token)
                    continuation.resume()
                } else {
                    waiting[token] = continuation
                }
            }
        } onCancel: {
            Task { @MainActor in
                guard let continuation = waiting.removeValue(forKey: token) else { return }
                abandoned.insert(token)
                continuation.resume()
            }
        }
        try Task.checkCancellation()
    }
}
#endif
