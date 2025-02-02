//
//  PerformanceMonitor.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-02.
//

import OSLog
import Foundation

@available(macOS 12.0, iOS 15.0, *)
@MainActor
final class PerformanceMonitor {
    static let standard = PerformanceMonitor()
    
    let signposter: OSSignposter
    var state: OSSignpostIntervalState?
    var startTime: DispatchTime = .now()
    static var executionTime: UInt64 = 0
    
    init() {
        signposter = OSSignposter(logger: Logger(OSLog(subsystem: "com.felfoldy.SwiftPy", category: .pointsOfInterest)))
    }
    
    @inlinable static func begin() {
        standard.state = standard.signposter.beginInterval("Python")
        standard.startTime = DispatchTime.now()
    }
    
    @inlinable static func end() {
        if let state = standard.state {
            executionTime = DispatchTime.now().uptimeNanoseconds - standard.startTime.uptimeNanoseconds
            standard.signposter.endInterval("Python", state)
        }
    }
}
