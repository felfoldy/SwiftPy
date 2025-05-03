//
//  ModelTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-03.
//

@testable import SwiftPy
import Testing
import Foundation
import SwiftData

@Suite("storages tests", .disabled("Unfinished API"))
@MainActor
struct ModelTests {
    @available(macOS 15, *)
    @Test func insertModel() throws {
        Interpreter.initStorages()
        
        Interpreter.run("""
        from storages import model, ModelContainer
        
        @model
        class Item:
            name: str = ''
            quantity: int = 0
            description: str | None
        
        sword = Item(name='Sword')
        container = ModelContainer('testing_container')
        container.insert(sword)
        """)
        
        // Backing data.
        let data = try #require(ModelData(Interpreter.evaluate("sword._data")))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)

        // Is inserted?
        let container = ModelContainer(.main["container"])
        let models = try container?.context.fetch(FetchDescriptor<ModelData>())
        #expect(models?.count == 1)
        #expect(models?.first?.id == data.id)
    }
}
