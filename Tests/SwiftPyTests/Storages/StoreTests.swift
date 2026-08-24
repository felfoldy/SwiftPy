//
//  StoreTests.swift
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
struct StoreTests {
    private let namespace = PyObject { py.newdict($0) }

    init() {
        try! run("""
        from modeling import model
        from storage import Store

        @model
        class Item:
            name: str = ''
            quantity: int = 0
            description: str | None
        """)
    }
    
    @available(macOS 15, *)
    @Test func insert() throws {
        try run("""
        container = Store('insert_testing', in_memory=True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        // Backing data.
        let data: ModelData = try #require(try evaluate("sword._data"))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
        #expect(data.keys?["__name__"] == "Item")
        
        // Is inserted?
        let container: SwiftPy.Store = try #require(try evaluate("container"))
        let models = try container.context.fetch(FetchDescriptor<ModelData>())
        #expect(models == [data])
    }
    
    @available(macOS 15, *)
    @Test func fetch() throws {
        try run("""
        container = Store('fetch_testing', True)
        container.insert(Item(name='Sword'))
        items = container.fetch(Item)
        print(items)
        print(items[0])
        print(len(items))
        """)

        let itemCount: Int = try #require(try evaluate("len(items)"))
        #expect(itemCount == 1)
        let data: ModelData = try #require(try evaluate("items[0]._data"))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
    }
    
    @available(macOS 15, *)
    @Test func update() throws {
        try run("""
        container = Store('update_testing', True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        // Backing data.
        let data: ModelData = try #require(try evaluate("sword._data"))
        #expect(data.json == #"{"name": "Sword", "quantity": 0, "description": null}"#)
        
        try run("""
        sword.description = "A great sword"
        sword.quantity += 1
        """)

        #expect(data.json == #"{"name": "Sword", "quantity": 1, "description": "A great sword"}"#)
    }
    
    @available(macOS 15, *)
    @Test func delete() throws {
        try run("""
        container = Store('delete_testing', True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        let insertedCount: Int = try #require(try evaluate("len(container.fetch(Item))"))
        #expect(insertedCount == 1)
        
        try run("container.delete(sword)")
        
        let deletedCount: Int = try #require(try evaluate("len(container.fetch(Item))"))
        #expect(deletedCount == 0)
        
        // Check reinser
        try run("container.insert(sword)")
        let reinsertedCount: Int = try #require(try evaluate("len(container.fetch(Item))"))
        #expect(reinsertedCount == 1)
    }

    @available(macOS 15, *)
    @Test func publicAPIAndDocumentation() throws {
        let publicClasses: [String] = try #require(try evaluate("""
        [name for name in ('Store', 'ModelData', 'LookupKeyValue') if hasattr(__import__('storage'), name)]
        """))
        #expect(publicClasses == ["Store"])

        let classDocs: String = try #require(try evaluate("Store.__doc__"))
        #expect(classDocs.contains("persistent collection"))

        let insertDocs: String = try #require(try evaluate("Store.insert.__doc__"))
        #expect(insertDocs.contains("Inserts a model instance"))
        #expect(insertDocs.contains("model: The model instance to insert."))

        let fetchDocs: String = try #require(try evaluate("Store.fetch.__doc__"))
        #expect(fetchDocs.contains("Returns all stored instances"))

        let deleteDocs: String = try #require(try evaluate("Store.delete.__doc__"))
        #expect(deleteDocs.contains("Deletes a model instance"))
    }

    private func run(_ source: String) throws {
        let code = try Interpreter.compile(source)
        try Interpreter.execute(code, globals: namespace)
    }

    private func evaluate<Result: PythonConvertible>(_ expression: String) throws -> Result? {
        let code = try Interpreter.compile(expression, mode: .evaluation)
        guard let result = try Interpreter.execute(code, globals: namespace) else {
            return nil
        }
        return try Result.cast(result.reference)
    }
}
