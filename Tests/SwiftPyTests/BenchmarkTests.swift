//
//  BenchmarkTests.swift
//  SwiftPy
//

#if cpython
import Testing
import Foundation
@testable import SwiftPy

/// The pybench cases that go through the whole execution path — task-locals,
/// tracer, output routing. Off by default; run with
/// `SWIFTPY_BENCH=1 swift test --filter BenchmarkTests`.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SWIFTPY_BENCH"] == "1"))
struct BenchmarkTests {
    private static let clock = ContinuousClock()

    private func report(_ name: String, _ duration: Duration) {
        let milliseconds = Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1e15
        print("bench \(name): \(String(format: "%.2f", milliseconds)) ms")
    }

    private func measure(_ name: String, _ body: () async throws -> Void) async rethrows {
        var samples: [Duration] = []
        for _ in 0..<5 {
            let start = Self.clock.now
            try await body()
            samples.append(start.duration(to: Self.clock.now))
        }
        report(name, samples.sorted()[2])
    }

    init() async {
        Interpreter.enableTrace()
        py.newmodule("bench")?.def("touch(value: int) -> int") { argc, argv in
            PyBind.function(argc, argv) { (value: Int) in value + 1 }
        }
        await Interpreter.run("""
        class Component:
            def __init__(self):
                self.ticks = 0

            def update(self, dt):
                self.ticks += 1
                return dt * 2

        component = Component()
        """)
    }

    @Test func bindingCalls() async throws {
        let code = try Interpreter.compile("""
        import bench
        for i in range(100_000):
            bench.touch(i)
        """, filename: "<script>/1", mode: .single)
        try await measure("100k binding calls") {
            try await Interpreter.execute(code)
        }
    }

    @Test func updateLatencyUnderLoad() async throws {
        let component = try #require(py.main.component)
        let busy = try Interpreter.compile("""
        import time
        deadline = time.monotonic() + 1.0
        n = 0
        while time.monotonic() < deadline:
            n += 1
        """, filename: "<script>/2", mode: .single)

        var latencies: [Duration] = []
        let cell = Task { @MainActor in
            try await Interpreter.execute(busy)
        }
        let end = Self.clock.now + .seconds(1.2)
        var wake = Self.clock.now + .milliseconds(1)
        while wake < end {
            try await Task.sleep(until: wake)
            try component.update?(0.3)
            latencies.append(wake.duration(to: Self.clock.now))
            wake = max(wake + .milliseconds(1), Self.clock.now)
        }
        _ = try await cell.value
        let sorted = latencies.sorted()
        report("update latency under load p50", sorted[sorted.count / 2])
        report("update latency under load p99", sorted[sorted.count * 99 / 100])
        report("update latency under load max", sorted[sorted.count - 1])
        print("bench update samples during the 1 s cell: \(latencies.count)")
    }

    @Test func awaits() async throws {
        let code = try Interpreter.compile("""
        import asyncio
        for i in range(10_000):
            await asyncio.sleep(0)
        """, filename: "<script>/3", mode: .single)
        try await measure("10k awaits") {
            try await Interpreter.execute(code)
        }
    }
}
#endif
