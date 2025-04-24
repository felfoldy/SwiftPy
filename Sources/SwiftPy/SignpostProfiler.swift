//
//  PerformanceMonitor.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import LogTools
import OSLog
import Foundation

public protocol Profiler {
    func begin()
    func end()
    func event(_ name: StaticString)
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

    @inlinable
    func event(_ name: StaticString) {
        Signposter.signposter.emitEvent(name)
    }
}

public class SignpostProfiler: Profiler {
    @usableFromInline
    var executionTime: UInt64 = 0

    @usableFromInline
    let signposter: Profiler?
    
    @usableFromInline
    var startTime: DispatchTime = .now()
    
    @usableFromInline
    var isProfiling: Bool = false

    public init(_ name: StaticString) {
        if #available(macOS 12.0, iOS 15.0, *) {
            signposter = Signposter(name: name)
        } else {
            signposter = nil
        }
    }
    
    deinit {
        if isProfiling { end() }
    }
    
    @inlinable
    public func begin() {
        startTime = .now()
        signposter?.begin()
        isProfiling = true
    }
    
    @inlinable
    public func end() {
        signposter?.end()
        let time = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        executionTime = time
        isProfiling = false
    }
    
    @inlinable
    public func event(_ name: StaticString) {
        signposter?.event(name)
    }
}
