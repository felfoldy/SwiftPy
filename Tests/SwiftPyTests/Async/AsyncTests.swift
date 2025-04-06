//
//  AsyncTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import Testing
@testable import SwiftPy

@MainActor
struct AsyncTests {
    let main = Interpreter.main
    
    @Test func codeToRun() {
        let decoder = AsyncDecoder("""
        await async_func()
        print('finished')
        """)
        
        #expect(decoder.code == "task = async_func()")
        #expect(decoder.continuationCode == "print('finished')")
    }
    
    @Test func result() {
        let decoder = AsyncDecoder("""
        result = await async_func()
        print(result)
        """)

        #expect(decoder.code == "task = async_func()")
        #expect(decoder.continuationCode == "print(result)")
        #expect(decoder.resultName == "result")
    }
    
    @Test func asyncRun() {
        main.bind(#def("async_func() -> AsyncTask") {
            AsyncTask {}
        })
        
        Interpreter.asyncRun("""
        await async_func()
        print('finished')
        """)
        
        #expect(main["task"]?["continuation_code"] == "print('finished')")
    }
    
    @Test func asyncRunWithResult() {
        main.bind(#def("async_func() -> AsyncTask") {
            AsyncTask { 42 }
        })
        
        Interpreter.asyncRun("""
        result = await async_func()
        print(result)
        """)
        
        #expect(main["task"]?["result"] == "result")
    }
}
