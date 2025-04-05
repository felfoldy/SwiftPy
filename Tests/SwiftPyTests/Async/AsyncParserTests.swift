//
//  AsyncParserTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import Testing
@testable import SwiftPy

@MainActor
struct AsyncParserTests {
    @Test func codeToRun() {
        let decoder = AsyncDecoder("""
        await async_func()
        print('finished')
        """)
        
        #expect(decoder.code == "task = async_func()")
        #expect(decoder.continuationCode == "print('finished')")
    }
    
    @Test func asyncRun() {
        Interpreter.main.bind(
            #def("async_func() -> AsyncTask") {
                AsyncTask {}
            }
        )
        
        Interpreter.asyncRun("""
        await async_func()
        print('finished')
        """)
        
        #expect(Interpreter.main["task"]?["continuation_code"] == "print('finished')")
    }
}
