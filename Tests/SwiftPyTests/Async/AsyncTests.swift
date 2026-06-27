//
//  AsyncTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import Testing
@testable import SwiftPy

@MainActor
func profile(_ name: StaticString) -> SignpostProfiler {
    let profiler = SignpostProfiler(name)
    profiler.begin()
    return profiler
}

@Suite("Async tests", .serialized)
@MainActor
struct AsyncTests {
    let main = py.main
    let profiler = profile("AsyncTests")
    
    @Test func codeToRun() {
        profiler.event("AsyncTests.codeToRun")

        let parsed = AsyncParser("""
        await URL.download()
        print('finished')
        """)

        #expect(parsed.code == "URL.download()")
        #expect(parsed.continuationCode == "print('finished')")
    }
    
    @Test func result() {
        profiler.event("AsyncTests.result")

        let parsed = AsyncParser("""
        result = await async_func()
        print(result)
        """)

        #expect(parsed.code == "async_func()")
        #expect(parsed.continuationCode == "print(result)")
        #expect(parsed.call == .awaiting(resultName: "result"))
    }
    
    @Test func asyncRun() async {
        profiler.event("AsyncTests.asyncRun")
        
        main.def("async_func() -> AsyncTask") { argc, argv in
            PyBind.function(argc, argv) {
                AsyncTask {}
            }
        }

        await Interpreter.run("""
        await async_func()
        finished = True
        """)
        
        #expect(main.finished == true)
    }
    
    @Test func asyncRunWithResult() async {
        profiler.event("AsyncTest.asyncRunWithResult")

        main.def("asyncRunWithResult() -> AsyncTask") { _, _ in
            PyAPI.return { AsyncTask { 42 } }
        }

        await Interpreter.run("""
        asyncRunWithResult_result = await asyncRunWithResult()
        """)

        #expect(main.asyncRunWithResult_result == 42)
    }
    
    @Test func chainingAsyncRun() async {
        profiler.event("AsyncTests.chainingAsyncRun")
        
        main.def("async_func() -> AsyncTask") { _, _ in
            PyAPI.return { AsyncTask { 42 } }
        }
        
        await Interpreter.run("""
        result = await async_func()
        """)
        
        await Interpreter.run("""
        new_result = result + 3
        """)
        
        #expect(main.new_result == 45)
    }
    
    @Test func asyncWithoutAwait() async throws {
        main.def("async_func() -> AsyncTask") { _, _ in
            PyAPI.return { AsyncTask { 42 } }
        }
        
        await Interpreter.run("""
        result = async_func()
        """)
        
        let task: AsyncTask? = main.result
        #expect(task != nil)
    }
    
    static var asyncTaskIterator_task: AsyncTask!
    
    @Test("AsyncTask iterator.")
    func asyncTaskIterator() async {
        main.def("async_func() -> AsyncTask") { _, _ in
            PyAPI.return {
                AsyncTests.asyncTaskIterator_task = AsyncTask { 1 }
                return AsyncTests.asyncTaskIterator_task
            }
        }

        await Interpreter.run("""
        def async_generator():
            a = await async_func()
            return a
        
        gen = async_generator()
        
        def iterate():
            try:
                next(gen)
                return None
            except StopIteration as e:
                return e.value
        """, mode: .single)
        
        #expect(Interpreter.evaluate("iterate()") == Int?.none)
        
        AsyncTests.asyncTaskIterator_task.isDone = true
        AsyncTests.asyncTaskIterator_task.result = py.retain(2)

        #expect(Interpreter.evaluate("iterate()") == 2)
    }
    
    @Test
    func asyncTaskFromGenerator() async throws {
        await Interpreter.run("""
        import asyncio
        
        async def asyncTaskFromGenerator_make():
            yield 1
            return 2
        """)
        
        await Interpreter.run("asyncTaskFromGenerator_result = await asyncTaskFromGenerator_make()")
        
        #expect(Interpreter.evaluate("asyncTaskFromGenerator_result") == 2)
    }
    
    @Test
    func chainAsyncTasks() async throws {
        main.def("chainAsyncTasks_task1() -> AsyncTask") { _,_ in
            PyAPI.return { AsyncTask { 3 } }
        }
        
        main.def("chainAsyncTasks_task2() -> AsyncTask") { _,_ in
            PyAPI.return { AsyncTask { 4 } }
        }
        
        await Interpreter.run("""
        async def chainAsyncTasks_make():
            a = await chainAsyncTasks_task1()
            print(f'a: {a}')
            b = await chainAsyncTasks_task2()
            print(f'b: {b}')
            return a * b
        """)
        
        await Interpreter.run("chainAsyncTasks_result = await chainAsyncTasks_make()")
        
        #expect(Interpreter.evaluate("chainAsyncTasks_result") == 12)
    }

    @Test func childFailing() async {
        await Interpreter.run("""
        childFailing_result = 0

        async def childFailing_child():
            raise RuntimeError("child failed")
            yield

        async def childFailing_parent():
            print("before")
            await childFailing_child()
            childFailing_result = 1
        """)
        
        await Interpreter.run("await childFailing_parent()")
        
        #expect(main.childFailing_result == 0)
    }
    
    @Test
    func asyncNotAGenerator() async throws {
        await Interpreter.run("""
        async def not_generator() -> str:
            return 'success'
        result = await not_generator()
        """)

        withKnownIssue {
            let result: String = try #require(py.main.result)
            #expect(result == "success")
        }
    }
    
    @Test
    func awaitedResultSurvivesGarbageCollection() async throws {
        main.def("gcCollectAfterAwait_some_other() -> AsyncTask") { _, _ in
            PyAPI.return { AsyncTask { 42 } }
        }

        await Interpreter.run("""
        async def gcCollectAfterAwait_something() -> int:
            import gc; gc.collect()
            result = await gcCollectAfterAwait_some_other()
            return result

        gcCollectAfterAwait_result = await gcCollectAfterAwait_something()
        """)

        let result: Int = try #require(py.main.gcCollectAfterAwait_result)
        #expect(result == 42)
    }
}
