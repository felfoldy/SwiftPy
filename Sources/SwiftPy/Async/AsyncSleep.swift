//
//  AsyncSleep.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-31.
//

import Foundation

@MainActor
@Scriptable
public final class AsyncSleep {
    public let seconds: Double
    public internal(set) var startDate = Date()
    public let task: AsyncTask

    public init(seconds: Double) {
        self.seconds = seconds
        let seconds = seconds
        task = AsyncTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }

        task.viewRepresentation = (self as? (any ViewRepresentable))?.representation
    }
}
