//
//  AsyncSleep.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-31.
//

@MainActor
@Scriptable
public final class AsyncSleep {
    internal var seconds: Double

    init(seconds: Double) {
        self.seconds = seconds
    }

    func __call__() async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
