//
//  ContainerTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-03.
//

@testable import SwiftPy
import Testing
import Foundation
import SwiftData

@MainActor
@Suite
struct ContainerTests {
    init() {
        Interpreter.run("""
        from modeling import model
        from storage import Container

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
        container = Container('insert_testing', True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        // Backing data.
        let data: ModelData = try #require(Interpreter.evaluate("sword._data"))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
        #expect(data.keys?["__name__"] == "Item")
        
        // Is inserted?
        let container: SwiftPy.Container? = py.main.container
        let models = try container?.context.fetch(FetchDescriptor<ModelData>())
        #expect(models == [data])
    }
    
    @available(macOS 15, *)
    @Test func fetch() throws {
        Interpreter.run("""
        container = Container('fetch_testing', True)
        container.insert(Item(name='Sword'))
        items = container.fetch(Item)
        print(items)
        print(items[0])
        print(len(items))
        """)

        #expect(Interpreter.evaluate("len(items)") == 1)
        let data: ModelData = try #require(Interpreter.evaluate("items[0]._data"))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
    }
    
    @available(macOS 15, *)
    @Test func update() throws {
        Interpreter.run("""
        container = Container('update_testing', True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        // Backing data.
        let data: ModelData = try #require(Interpreter.evaluate("sword._data"))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
        
        Interpreter.run("""
        sword.description = "A great sword"
        sword.quantity += 1
        """)

        #expect(data.json == #"{"name": "Sword", "quantity": 1, "description": "A great sword"}"#)
    }
    
    @available(macOS 15, *)
    @Test func delete() throws {
        Interpreter.run("""
        container = Container('delete_testing', True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        #expect(Interpreter.evaluate("len(container.fetch(Item))") == 1)
        
        Interpreter.run("container.delete(sword)")
        
        #expect(Interpreter.evaluate("len(container.fetch(Item))") == 0)
        
        // Check reinser
        Interpreter.run("container.insert(sword)")
        #expect(Interpreter.evaluate("len(container.fetch(Item))") == 1)
    }
}
