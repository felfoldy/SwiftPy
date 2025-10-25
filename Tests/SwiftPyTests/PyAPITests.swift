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
    @Test func setAttribute() {
        let main = Interpreter.main

        Interpreter.execute("class Test: ...")

        main["Test"]?.bind("__init__(self, val: str) -> None") { argc, argv in
            PyAPI.returnNone {
                argv?.setAttribute("param", argv?[1])
            }
        }

        Interpreter.execute("""
        x = Test('secret value')
        """)

        #expect(main["x"]?["param"] == "secret value")
        
        main["x"]?.deleteAttribute("param")
        
        #expect(main["x"]?["param"] == nil)
    }
    
    @Test func referenceCall() throws {
        Interpreter.run("""
        def add(a, b):
            return a + b
        """)
        
        let addFunction = Interpreter.main["add"]
        let a = 10.toStack
        let b = 20.toStack
        let sum = try addFunction?.call([a.reference, b.reference])
            .toStack
        
        #expect(sum?.reference == 30)
    }
}
