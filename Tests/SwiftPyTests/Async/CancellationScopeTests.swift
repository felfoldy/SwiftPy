//
//  CancellationScopeTests.swift
//  SwiftPy
//

#if cpython
import Foundation
import Synchronization
import Testing
import SwiftUI
@testable import SwiftPy

// On the cell's thread, where `time.sleep` waits in Swift.
@PythonActor
private func call(_ function: PyObject) throws -> PyObject {
    try PyRuntime.call(function)
}

@MainActor
@Suite(.serialized)
struct CancellationScopeTests {
    init() async {
        await Interpreter.run("""
        import time

        def _nap():
            try:
                time.sleep(30)
                return "slept"
            except BaseException as error:
                return type(error).__name__
        """)
    }

    private var nap: PyObject { py.main._nap! }

    @Test func cancellingAScopeEndsASleepInsideIt() async throws {
        let started = ContinuousClock.now
        let result = try await Interpreter.withCancellationScope { scope in
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(100))
                scope.cancel()
            }
            return String(try await call(nap))
        }
        #expect(result == "CancelledError")
        #expect(ContinuousClock.now - started < .seconds(5))
    }

    @Test func stoppingTheRunEndsTheScope() async throws {
        let run = RunCancellation()
        let started = ContinuousClock.now
        let result = try await InterpreterExecutionContext.withOutput(cancellation: run, operation: { @MainActor in
            try await Interpreter.withCancellationScope { scope in
                Task { @MainActor in
                    try await Task.sleep(for: .milliseconds(100))
                    run.cancel()
                }
                let result = String(try await call(nap))
                #expect(scope.isCancelled)
                return result
            }
        }, stdout: { _ in })
        // A stop, as it is for code that isn't waiting.
        #expect(result == "KeyboardInterrupt")
        #expect(ContinuousClock.now - started < .seconds(5))
    }

    @Test func aScopeLeavesTheRestOfTheRunAlone() async throws {
        let run = RunCancellation()
        try await InterpreterExecutionContext.withOutput(cancellation: run, operation: { @MainActor in
            try await Interpreter.withCancellationScope { scope in scope.cancel() }
        }, stdout: { _ in })
        #expect(!run.isCancelled)
    }

    @Test func displayedViewsCanBeTakenToo() async throws {
        _ = AnyView.pyType
        _ = CustomView.pyType
        py.main._shown_view = CustomView()
        await Interpreter.run("""
        import asyncio
        from interpreter import display

        async def _show():
            display(_shown_view)
            await asyncio.sleep(0)
            display(_shown_view)
        """)
        var shown = 0
        var interfaceShown = 0
        Interpreter.interface.display = { _ in interfaceShown += 1 }
        defer { Interpreter.interface.display = InterpreterInterface().display }

        try await Interpreter.withOutput(to: { _ in }, display: { _ in shown += 1 }) {
            _ = try await AsyncTask.from(try PyRuntime.call(py.main._show!)).untilCompletes()
        }
        #expect(shown == 2)
        #expect(interfaceShown == 0)
    }

    @Test func outputCanBeTakenWithoutLosingTheStop() async throws {
        await Interpreter.run("""
        import asyncio

        def _say():
            print("sync")
            return _nap()

        async def _later():
            await asyncio.sleep(0)
            print("async")
        """)
        let run = RunCancellation()
        let taken = Mutex("")
        let runOutput = Mutex("")
        let result = try await InterpreterExecutionContext.withOutput(cancellation: run, operation: { @MainActor in
            try await Interpreter.withOutput(to: { text in taken.withLock { $0 += text } }) {
                try await AsyncTask.from(try PyRuntime.call(py.main._later!)).untilCompletes()
                Task { @MainActor in
                    try await Task.sleep(for: .milliseconds(100))
                    run.cancel()
                }
                return String(try await call(py.main._say!))
            }
        }, stdout: { text in runOutput.withLock { $0 += text } })

        #expect(result == "KeyboardInterrupt")
        #expect(taken.withLock { $0 } == "async\nsync\n")
        #expect(runOutput.withLock { $0 }.isEmpty)
    }

    @Test func sleepOffTheCellsThreadStillSleeps() throws {
        // Main can't wait in Swift, so there it's the C sleep.
        try PyRuntime.run("import time\ntime.sleep(0.01)\n_slept_on_main = True")
        #expect(Interpreter.evaluate("_slept_on_main") == true)
    }
}
#endif
