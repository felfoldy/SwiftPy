//
//  SwiftEventLoopTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-13.
//

#if cpython
import Testing
@testable import SwiftPy

// The stdlib asyncio on the Swift-driven loop, and AsyncTask bridging both ways.
@Suite(.serialized)
@MainActor
struct SwiftEventLoopTests {
    private func run(_ source: String) async throws(PythonError) {
        try await Interpreter.execute(try Interpreter.compile(source))
    }

    @Test func loopIsRunningFromTheStart() async throws {
        try await run("""
        import asyncio
        loop = asyncio.get_running_loop()
        assert type(loop).__name__ == 'SwiftEventLoop'
        assert asyncio.get_event_loop() is loop
        """)
    }

    @Test func stdlibPrimitives() async throws {
        try await run("""
        import asyncio
        async def delayed(v, s):
            await asyncio.sleep(s); return v
        assert await asyncio.gather(delayed('slow', 0.05), delayed('fast', 0.01)) == ['slow', 'fast']
        t = asyncio.create_task(delayed(1, 0.01))
        assert isinstance(t, asyncio.Task) and await t == 1
        async with asyncio.TaskGroup() as tg:
            a = tg.create_task(delayed(1, 0.01)); b = tg.create_task(delayed(2, 0.01))
        assert a.result() + b.result() == 3
        ev = asyncio.Event()
        asyncio.create_task(delayed(ev.set(), 0)); await asyncio.sleep(0.01)
        assert ev.is_set()
        try:
            await asyncio.wait_for(delayed('x', 1), timeout=0.02); assert False
        except TimeoutError: pass
        assert isinstance(asyncio.current_task(), asyncio.Task)
        """)
    }

    @Test func pythonAwaitsSwiftWork() async throws {
        let host = py.newmodule("loop_test_host")!
        host.asyncDef("fetch(value: int) -> int") { argc, argv in
            PyBind.function(argc, argv) { (value: Int) -> AsyncTask in
                AsyncTask { () async throws -> Int in
                    try await Task.sleep(for: .milliseconds(10))
                    return value * 2
                }
            }
        }
        host.asyncDef("boom() -> None") { argc, argv in
            PyBind.function(argc, argv) { () -> AsyncTask in
                AsyncTask { () async throws -> Int in throw PythonError.ValueError("from swift") }
            }
        }
        try await run("""
        import asyncio, loop_test_host as host
        assert await host.fetch(21) == 42
        assert await asyncio.gather(host.fetch(1), host.fetch(2)) == [2, 4]
        try:
            await host.boom(); assert False
        except ValueError as e:
            assert 'from swift' in str(e)
        """)
    }

    @Test func coroutineErrorReachesSwift() async {
        await #expect(throws: PythonError.self) {
            try await run("""
            async def f(): raise KeyError('nope')
            await f()
            """)
        }
    }

    @Test func printInsideTasksIsCaptured() async {
        let output = await Interpreter.withOutputCapture {
            try? await run("""
            import asyncio
            async def talk():
                print('a'); await asyncio.sleep(0.01); print('b')
            await asyncio.gather(talk(), talk())
            """)
        }
        #expect(output == "a\na\nb\nb\n")
    }

    @Test func cancelFromSwift() async throws {
        try await run("""
        import asyncio
        cancelled = False
        async def long():
            global cancelled
            try:
                await asyncio.sleep(5)
            except asyncio.CancelledError:
                cancelled = True
                raise
        coro = long()
        """)
        let task = try AsyncTask.from(py.main.coro!)
        task.resume()
        try await Task.sleep(for: .milliseconds(20))
        task.cancel()
        try await Task.sleep(for: .milliseconds(20))
        #expect(py.main.cancelled == true)
        #expect(task.isDone)
    }

    @Test func asyncioRunExplainsItself() async throws {
        try await run("""
        import asyncio
        try:
            asyncio.run(asyncio.sleep(0)); assert False
        except RuntimeError as e:
            assert 'await' in str(e)
        """)
    }
}
#endif
