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
    
    @MainActor static var callback: (() -> Void)?

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            lastText = text
        }
       
        print("TestIntent - text: \(text)")

        // Just to continue the execution.
        await MainActor.run { Self.callback?() }

        return .result()
    }
}

@MainActor
@Suite(
    "Intents",
    .tags(.experimental)
)
struct IntentsTests {
    @Test func register() async throws {
        Interpreter.register(TestIntent.self)
        
        await Interpreter.asyncRun("""
        from intents import TestIntent
        
        await TestIntent('call')
        
        print("finished")
        """)

        #expect(lastText == "call")
    }
}

@MainActor private var lastText: String? = nil
