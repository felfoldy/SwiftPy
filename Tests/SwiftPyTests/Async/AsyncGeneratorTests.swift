//
//  AsyncGeneratorTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-03-06.
//

import Testing
import SwiftPy

struct AsyncGeneratorTests {
    @Test
    func childFailing() async {
        await Interpreter.asyncRun("""
        import asyncio as _asyncio

        @_asyncio.coroutine
        def child():
            raise RuntimeError("child failed")
            yield

        @_asyncio.coroutine
        def parent():
            print("before")
            yield from child()
            print("after")   # should never run
        """)
        
        await Interpreter.asyncRun("await parent()")
    }
}
