//
//  BlockingBindingTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-21.
//

#if cpython
import Testing
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct BlockingBindingTests {
    init() {
        PyBind.module("blocking_probe") { module in
            module.def("answer(delay: float) -> int") { argc, argv in
                PyBind.blocking(argc, argv) { (delay: Double) in
                    try await Task.sleep(for: .seconds(delay))
                    return 42
                }
            }
            module.def("failing() -> None") { argc, argv in
                PyBind.blocking(argc, argv) {
                    throw PythonError.ValueError("no")
                }
            }
        }
    }

    @Test func aCellGetsTheValueWithoutAwaiting() async {
        await Interpreter.run("""
        import blocking_probe
        blocking_answer = blocking_probe.answer(0.02)
        try:
            blocking_probe.failing()
        except ValueError as error:
            blocking_failure = str(error)
        """)
        #expect(Interpreter.evaluate("blocking_answer") == 42)
        #expect(Interpreter.evaluate("blocking_failure") == "no")
    }

    @Test func mainCannotWait() {
        let result: Int? = Interpreter.evaluate("__import__('blocking_probe').answer(0)")
        #expect(result == nil)
    }

    @Test func aStopEndsTheWait() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events
        await connection.compile(id: 1, source: """
        import blocking_probe
        blocking_stopped = 'waiting'
        try:
            blocking_probe.answer(10)
        finally:
            blocking_stopped = 'unwound'
        """)

        var iterator = stream.makeAsyncIterator()
        let runTask = Task { await connection.run(id: 1) }
        for _ in 0..<200 where (Interpreter.evaluate("blocking_stopped") as String?) != "waiting" {
            try? await Task.sleep(for: .milliseconds(10))
        }

        let clock = ContinuousClock()
        let start = clock.now
        await connection.perform(.stop(id: 1))
        await runTask.value
        #expect(start.duration(to: clock.now) < .seconds(1))

        var stopped = false
        while let event = await iterator.next() {
            if case .stopped = event.payload, event.id == 1 {
                stopped = true
                break
            }
        }
        #expect(stopped)
        #expect(Interpreter.evaluate("blocking_stopped") == "unwound")
    }
}
#endif
