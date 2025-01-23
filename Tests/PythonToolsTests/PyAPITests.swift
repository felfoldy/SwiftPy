//
//  PyAPITests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import Testing
import PythonTools

@MainActor
@Test func settAttribute() {
    let __init__ = #def("__init__(self, val: str) -> None") { args in
        args[0]?.setAttribute("param", args[1])
    }

    Interpreter.execute("class Test: ...")

    Interpreter.main["Test"]?.bind(__init__)

    Interpreter.execute("""
    x = Test('secret value')
    """)

    #expect(Interpreter.main["x"]?["param"] == "secret value")
}
