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

@MainActor
struct ModelContainerTests {
    init() {
        Interpreter.run("""
        from storages import model, ModelContainer

        @model
        class Item:
            name: str = ''
            quantity: int = 0
            description: str | None
        """)
    }
    
    @available(macOS 15, *)
    @Test func insert() throws {
        Interpreter.run("""
        container = ModelContainer('insert_testing')
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        // Backing data.
        let data = try #require(ModelData(Interpreter.evaluate("sword._data")))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
        #expect(data.keys["__name__"] == "Item")
        
        // Is inserted?
        let container = ModelContainer(.main["container"])
        let models = try container?.context.fetch(FetchDescriptor<ModelData>())
        #expect(models == [data])
    }
    
    @available(macOS 15, *)
    @Test func fetch() throws {
        Interpreter.run("""
        container = ModelContainer('fetch_testing')
        container.insert(Item(name='Sword'))
        items = container.fetch(Item)
        """)

        #expect(Interpreter.evaluate("len(items)") == 1)
        let data = try #require(ModelData(Interpreter.evaluate("items[0]._data")))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
    }
}
