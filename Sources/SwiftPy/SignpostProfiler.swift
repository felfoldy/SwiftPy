//
//  PerformanceMonitor.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import OSLog
import Foundation

public protocol Profiler {
    func begin()
    func end()
}

@available(macOS 12.0, iOS 15.0, *)
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
}

public class SignpostProfiler: Profiler {
    @usableFromInline
    var executionTime: UInt64 = 0

    @usableFromInline
    let signposter: Profiler?
    
    @usableFromInline
    var startTime: DispatchTime = .now()
    
    init(_ name: StaticString) {
        if #available(macOS 12.0, iOS 15.0, *) {
            signposter = Signposter(name: name)
        } else {
            signposter = nil
        }
    }
    
    @inlinable
    public func begin() {
        startTime = .now()
        signposter?.begin()
    }
    
    @inlinable
    public func end() {
        signposter?.end()
        executionTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
    }
}
