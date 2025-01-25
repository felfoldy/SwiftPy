//
//  ConversionTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-26.
//

import SwiftPy
import Testing
import pocketpy

@MainActor
struct ConversionTests {
    @Test func strArrayToPython() {
        let array: [String] = ["Hello", "World"]
        
        Interpreter.execute("x = []")
        array.toPython(Interpreter.main["x"])
        
        #expect(Interpreter.main["x"] == ["Hello", "World"])
    }
}
