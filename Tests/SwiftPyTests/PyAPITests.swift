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
        
        let __init__ = #def("__init__(self, val: str) -> None") { args in
            args[0]?.setAttribute("param", args[1])
        }

        Interpreter.execute("class Test: ...")

        main["Test"]?.bind(__init__)

        Interpreter.execute("""
        x = Test('secret value')
        """)

        #expect(main["x"]?["param"] == "secret value")
        
        main["x"]?.deleteAttribute("param")
        
        #expect(main["x"]?["param"] == nil)
    }
}
