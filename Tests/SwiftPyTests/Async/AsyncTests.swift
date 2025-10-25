//
//  AsyncTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import Testing
@testable import SwiftPy
import LogTools

func profile(_ name: StaticString) -> SignpostProfiler {
    let profiler = SignpostProfiler(name)
    profiler.begin()
    return profiler
}

@Suite("Async tests", .serialized)
@MainActor
struct AsyncTests {
    let main = Interpreter.main
    let profiler = profile("AsyncTests")
    
    @Test func codeToRun() {
        profiler.event("AsyncTests.codeToRun")

        let decoder = AsyncContext("""
        await URL.download()
        print('finished')
        """, filename: "<string>", mode: .execution) {}
        
        #expect(decoder.code == "URL.download()")
        #expect(decoder.continuationCode == "print('finished')")
    }
    
    @Test func result() {
        profiler.event("AsyncTests.result")
        
        let decoder = AsyncContext("""
        result = await async_func()
        print(result)
        """, filename: "<string>", mode: .evaluation) {}

        #expect(decoder.code == "async_func()")
        #expect(decoder.continuationCode == "print(result)")
        #expect(decoder.resultName == "result")
    }
    
    @Test func asyncRun() async {
        profiler.event("AsyncTests.asyncRun")
        
        main.bind("async_func() -> AsyncTask") { argc, argv in
            PyBind.function(argc, argv) {
                AsyncTask {}
            }
        }
        
        await Interpreter.asyncRun("""
        await async_func()
        finished = True
        """)
        
        #expect(main["finished"] == true)
    }
    
    @Test func asyncRunWithResult() async {
        profiler.event("AsyncTest.asyncRunWithResult")

        main.bind("asyncRunWithResult() -> AsyncTask") { _, _ in
            PyAPI.return(AsyncTask { 42 })
        }

        await Interpreter.asyncRun("""
        asyncRunWithResult_result = await asyncRunWithResult()
        """)

        #expect(main["asyncRunWithResult_result"] == 42)
    }
    
    @Test func chainingAsyncRun() async {
        profiler.event("AsyncTests.chainingAsyncRun")
        
        main.bind("async_func() -> AsyncTask") { _, _ in
            PyAPI.return(AsyncTask { 42 })
        }
        
        await Interpreter.asyncRun("""
        result = await async_func()
        """)
        
        await Interpreter.asyncRun("""
        new_result = result + 3
        """)
        
        #expect(main["new_result"] == 45)
    }
    
    @Test func asyncWithoutAwait() async {
        main.bind("async_func() -> AsyncTask") { _, _ in
            PyAPI.return(AsyncTask { 42 })
        }
        
        await Interpreter.asyncRun("""
        result = async_func()
        """)
        
        #expect(AsyncTask(.main["result"]) != nil)
    }
    
    static var asyncTaskIterator_task: AsyncTask!
    
    @Test("AsyncTask iterator.")
    func asyncTaskIterator() async {
        main.bind("async_func() -> AsyncTask") { _, _ in
            PyAPI.returnOrThrow {
                AsyncTests.asyncTaskIterator_task = AsyncTask { 1 }
                return AsyncTests.asyncTaskIterator_task
            }
        }

        await Interpreter.asyncRun("""
        def async_generator():
            a = yield from async_func()
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
        AsyncTests.asyncTaskIterator_task[.result] = 2

        #expect(Interpreter.evaluate("iterate()") == 2)
    }
    
    @Test
    func asyncTaskFromGenerator() async throws {
        Interpreter.run("""
        import asyncio
        
        @asyncio.coroutine
        def asyncTaskFromGenerator_make():
            yield 1
            return 2
        """)
        
        await Interpreter.asyncRun("asyncTaskFromGenerator_result = await asyncTaskFromGenerator_make()")
        
        #expect(Interpreter.evaluate("asyncTaskFromGenerator_result") == 2)
    }
    
    @Test
    func chainAsyncTasks() async throws {
        Interpreter.main.bind("chainAsyncTasks_task1() -> AsyncTask") { _,_ in
            PyAPI.return(AsyncTask { 3 })
        }
        
        Interpreter.main.bind("chainAsyncTasks_task2() -> AsyncTask") { _,_ in
            PyAPI.return(AsyncTask { 4 })
        }
        
        Interpreter.run("""
        import asyncio
            
        @asyncio.coroutine
        def chainAsyncTasks_make():
            a = yield from chainAsyncTasks_task1()
            print(f'a: {a}')
            b = yield from chainAsyncTasks_task2()
            print(f'b: {b}')
            return a * b
        """)
        
        await Interpreter.asyncRun("chainAsyncTasks_result = await chainAsyncTasks_make()")
        
        #expect(Interpreter.evaluate("chainAsyncTasks_result") == 12)
    }
}
