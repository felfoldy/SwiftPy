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

@Suite("Async tests", .disabled("Unstable feature"))
@MainActor
struct AsyncTests {
    let main = Interpreter.main
    let profiler = profile("AsyncTests")
    
    @Test func codeToRun() {
        profiler.event("AsyncTests.codeToRun")

        let decoder = AsyncDecoder("""
        await URL.download()
        print('finished')
        """)
        
        #expect(decoder.code == "task = URL.download()")
        #expect(decoder.continuationCode == "print('finished')")
    }
    
    @Test func result() {
        profiler.event("AsyncTests.result")
        
        let decoder = AsyncDecoder("""
        result = await async_func()
        print(result)
        """)

        #expect(decoder.code == "task = async_func()")
        #expect(decoder.continuationCode == "print(result)")
        #expect(decoder.resultName == "result")
    }
    
    @Test func asyncRun() async {
        profiler.event("AsyncTests.asyncRun")
        
        main.bind(#def("async_func() -> AsyncTask") {
            AsyncTask {}
        })
        
        await Interpreter.asyncRun("""
        await async_func()
        finished = True
        """)
        
        #expect(main["finished"] == true)
    }
    
    @Test func asyncRunWithResult() async {
        profiler.event("AsyncTest.asyncRunWithResult")

        main.bind(#def("async_func() -> AsyncTask") {
            AsyncTask { 42 }
        })
        
        await Interpreter.asyncRun("""
        result = await async_func()
        """)
        
        #expect(main["result"] == 42)
    }
    
    @Test func chainingAsyncRun() async {
        profiler.event("AsyncTests.chainingAsyncRun")
        
        main.bind(#def("async_func() -> AsyncTask") {
            AsyncTask { 42 }
        })
        
        await Interpreter.asyncRun("""
        result = await async_func()
        """)
        
        await Interpreter.asyncRun("""
        new_result = result + 3
        """)
        
        #expect(main["new_result"] == 45)
    }
}
