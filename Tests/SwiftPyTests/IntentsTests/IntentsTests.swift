//
//  IntentsTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-22.
//

import Testing
import SwiftPy
import AppIntents

struct TestIntent: AppIntent {
    static let title = LocalizedStringResource("title")
    
    @Parameter(title: "Text")
    var text: String

    func perform() async throws -> some IntentResult {
        lastText = text
        print("TestIntent - text: \(text)")
        return .result()
    }
}

@MainActor
struct IntentsTests {
    @Test func register() async throws {
        Interpreter.register(TestIntent.self)

        await withUnsafeContinuation { continuation in
            Interpreter.main.bind(#def("intent_result() -> None") {
                continuation.resume()
            })
            
            Interpreter.run("""
            from intents import TestIntent
            TestIntent('call').resume = intent_result
            """)
        }

        #expect(lastText == "call")
    }
}

nonisolated(unsafe) private var lastText: String? = nil
