//
//  StoppableTests.swift
//  SwiftPy
//

#if cpython
import Foundation
import Testing
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct StoppableTests {
    @Test func returnsWhatTheCallReturns() async {
        await Interpreter.run("""
        from interpreter import stoppable
        import threading

        @stoppable
        def _where(x, *, y):
            return (x + y, threading.get_ident() != _cell)

        _cell = threading.get_ident()
        _result = _where(1, y=2)
        """)
        // On a worker, not the cell's thread.
        #expect(Interpreter.evaluate("str(_result)") == "(3, True)")
    }

    @Test func raisesWhatTheCallRaises() async {
        await Interpreter.run("""
        from interpreter import stoppable
        import time

        @stoppable
        def _fail():
            raise LookupError("missing")

        try:
            _fail()
        except LookupError as error:
            _raised = str(error)

        try:
            time.sleep(-1)
        except ValueError as error:
            _negative = str(error)
        """)
        #expect(Interpreter.evaluate("_raised") == "missing")
        #expect(Interpreter.evaluate("_negative") == "sleep length must be non-negative")
    }

    @Test func keepsTheNameAndDocs() async {
        await Interpreter.run("import time\n_name = time.sleep.__name__\n_doc = bool(time.sleep.__doc__)")
        #expect(Interpreter.evaluate("_name") == "sleep")
        #expect(Interpreter.evaluate("_doc") == true)
    }

    @Test func aStopEndsTheWait() async {
        let connection = LocalInterpreterConnection()
        await connection.compile(id: 1, source: """
        from interpreter import stoppable
        import threading

        _test_release = threading.Event()

        @stoppable
        def _blocked():
            _test_release.wait()

        _test_stoppable_flag = 'waiting'
        _blocked()
        _test_stoppable_flag = 'returned'
        """)

        let started = ContinuousClock.now
        let runTask = Task { await connection.run(id: 1) }
        for _ in 0..<200 where (Interpreter.evaluate("_test_stoppable_flag") as String?) != "waiting" {
            try? await Task.sleep(for: .milliseconds(10))
        }
        try? await Task.sleep(for: .milliseconds(50))
        await connection.perform(.stop(id: 1))
        await runTask.value

        #expect(ContinuousClock.now - started < .seconds(5))
        #expect(Interpreter.evaluate("_test_stoppable_flag") == "waiting")
        // The abandoned call finishes later, with nothing waiting for it.
        await Interpreter.run("_test_release.set()")
    }
}
#endif
