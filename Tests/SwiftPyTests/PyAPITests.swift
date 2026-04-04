//
//  PyAPITests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import Testing
import SwiftPy

@MainActor
struct PyAPITests {
    @Test func setAttribute() throws {
        let main = PyModule.main

        Interpreter.execute("class Test: ...")

        main.Test?.reference.bind("__init__(self, val: str) -> None") { argc, argv in
            PyAPI.returnNone {
                argv?.setAttribute("param", argv?[1])
            }
        }
        
        Interpreter.execute("""
        x = Test('secret value')
        """)

        #expect(main.x?.param == "secret value")
        
        main.x?.param = nil
                
        #expect(main.x?.param == nil)
    }
    
    @Test func referenceCall() throws {
        Interpreter.run("""
        def add(a, b):
            return a + b
        """)
        
        try #expect(PyModule.main.add?(10, 20) == 30)
    }
    
    @Test func referenceCallThrows() throws {
        Interpreter.run("""
        def referenceCallThrows():
            raise ValueError('incorrect')
        """)
        
        #expect(throws: PythonError.self) {
            try PyModule.main.referenceCallThrows?()
        }
    }
}
