//
//  PerformanceMonitor.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import OSLog
import Foundation

@MainActor
public protocol Profiler {
    func begin()
    func end()
    func event(_ name: StaticString)
}

final class Signposter: Profiler {
    static let signposter = OSSignposter(
        logger: Logger(
            OSLog(subsystem: "com.felfoldy.SwiftPy",
                  category: .pointsOfInterest)
        )
    )

    let name: StaticString
    
    init(name: StaticString) {
        self.name = name
    }
    
    private var state: OSSignpostIntervalState?
    
    @inlinable
    func begin() {
        state = Signposter.signposter
            .beginInterval(name)
    }
    
    @inlinable
    func end() {
        if let state = state {
            Signposter.signposter
                .endInterval(name, state)
        }
    }

    @inlinable
    func event(_ name: StaticString) {
        Signposter.signposter.emitEvent(name)
    }
}

public class SignpostProfiler: Profiler {
    @usableFromInline
    let signposter: Profiler?
    
    @usableFromInline
    var isProfiling: Bool = false

    public init(_ name: StaticString) {
        signposter = Signposter(name: name)
    }
    
    @MainActor deinit {
        if isProfiling { end() }
    }
    
    @inlinable
    public func begin() {
        signposter?.begin()
        isProfiling = true
    }
    
    @inlinable
    public func end() {
        signposter?.end()
        isProfiling = false
    }
    
    @inlinable
    public func event(_ name: StaticString) {
        signposter?.event(name)
    }
}
