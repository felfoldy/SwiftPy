//
//  DisplayJSONTests.swift
//  SwiftPy
//

import Testing
@testable import SwiftPy

@MainActor
@Suite("display json markdown")
struct DisplayJSONTests {
    init() {
        Interpreter.run("import interpreter")
    }

    private func markdown(_ source: String) -> String? {
        let object: PyObject? = Interpreter.evaluate(source)
        return object?.reference.jsonMarkdown
    }

    @Test func dictIsPrettyPrintedInAJSONBlock() {
        #expect(markdown("{'name': 'pikachu', 'id': 25}") == """
        ```json
        {
          "name": "pikachu",
          "id": 25
        }
        ```
        """)
    }

    @Test func listOfDictsIsIndented() {
        #expect(markdown("[{'name': 'electric'}]") == """
        ```json
        [
          {
            "name": "electric"
          }
        ]
        ```
        """)
    }

    @Test func scalarsKeepTheirRepr() {
        #expect(markdown("'text'") == nil)
        #expect(markdown("25") == nil)
        #expect(markdown("None") == nil)
    }

    @Test func aDictJSONCannotHoldIsNotRendered() {
        #expect(markdown("{'set': set()}") == nil)
    }
}
