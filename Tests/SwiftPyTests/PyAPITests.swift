//
//  PyAPITests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import Testing
import SwiftPy

@MainActor
@Suite(.serialized)
struct PyAPITests {
    // PyRef.bind is pocketpy's; CPython binds through PyType/PyModule.
    #if !cpython
    @Test func setAttribute() async throws {
        let main = py.main

        await Interpreter.run("class Test: ...")

        let Test = main.Test

        Test?.reference.bind("__init__(self, val: str) -> None") { argc, argv in
            PyAPI.return {
                if let argv {
                    try py.setattr(argv, name: "param", value: argv[1])
                }
                return .none
            }
        }
        
        await Interpreter.run("""
        x = Test('secret value')
        """)

        #expect(main.x?.param == "secret value")
        
        main.x?.param = nil
                
        #expect(main.x?.param == nil)
    }
    
    #endif

    @Test func referenceCall() async throws {
        await Interpreter.run("""
        def add(a, b):
            return a + b
        """)
        
        try #expect(py.main.add?(10, 20) == 30)
    }
    
    @Test func referenceCallThrows() async throws {
        await Interpreter.run("""
        def referenceCallThrows():
            raise ValueError('incorrect')
        """)

        #expect(throws: PythonError.self) {
            try py.main.referenceCallThrows?()
        }
    }

    @Test func errorToPython() async {
        py.main.err = PythonError.ValueError("boom")

        await Interpreter.run("""
        def reraise():
            raise err
        """)

        let error = #expect(throws: PythonError.self) {
            try py.main.reraise?()
        }
        #expect(error?.type == .ValueError)
        #expect(String(describing: error?.value ?? "") == "boom")
    }

    @Test func errorToPythonRoundTrip() throws {
        py.main.err = PythonError.KeyError("missing")

        let error = try #require(PythonError(py.main.err))
        #expect(error.type == .KeyError)
        #if cpython
        // str() of a KeyError is the repr of its key.
        #expect(String(describing: error.value) == "'missing'")
        #else
        #expect(String(describing: error.value) == "missing")
        #endif
    }

    @Test func errorDescriptionFallsBackToValue() {
        let error = PythonError.ValueError("boom")

        #expect(error.errorDescription == "boom")
    }

    @Test func errorDescriptionUsesTraceback() {
        let error = PythonError.ValueError("boom")
            .withTraceback("Traceback (most recent call last):\nValueError: boom")

        #expect(error.errorDescription == "Traceback (most recent call last):\nValueError: boom")
    }
}
