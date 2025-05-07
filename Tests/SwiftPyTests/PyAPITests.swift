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
    /// `.set` is the assignment operator however a custom operator would be better maybe.
    @Test func set() {
        Interpreter.execute("x = 10")
        #expect(Interpreter.main["x"] == 10)

        Interpreter.main["x"]?.set(Int?.none)
        #expect(Interpreter.main["x"]?.isNone == true)
        
        Interpreter.main["x"]?.set("10")
        #expect(Interpreter.main["x"] == "10")
    }
    
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
}
