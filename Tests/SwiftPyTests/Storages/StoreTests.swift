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
    private let namespace: PyObject

    init() throws {
        let code = try Interpreter.compile("{'__builtins__': __import__('builtins')}", mode: .evaluation)
        namespace = try #require(try Interpreter.execute(code))
        try run("""
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
        let handle: ModelHandle = try #require(try evaluate("sword._data"))
        #expect(handle.json == #"{"name": "Sword", "quantity": 0, "description": null, "_icloud_id": null}"#)
        
        // Is inserted?
        let container: SwiftPy.Store = try #require(try evaluate("container"))
        let row = try #require(try container.row(id: handle.id))
        #expect(row.json == handle.json)
        #expect(row.keys?["__name__"] == "Item")
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
        let handle: ModelHandle = try #require(try evaluate("items[0]._data"))
        #expect(handle.json == #"{"name": "Sword", "quantity": 0, "description": null, "_icloud_id": null}"#)
    }
    
    @available(macOS 15, *)
    @Test func update() throws {
        try run("""
        container = Store('update_testing', True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        
        let container: SwiftPy.Store = try #require(try evaluate("container"))
        let handle: ModelHandle = try #require(try evaluate("sword._data"))
        
        try run("""
        sword.description = "A great sword"
        sword.quantity += 1
        """)

        let row = try #require(try container.row(id: handle.id))
        #expect(row.json == #"{"name": "Sword", "quantity": 1, "description": "A great sword", "_icloud_id": null}"#)
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

        // Unstored: a change no longer reaches the store.
        let isUnstored: Bool = try #require(try evaluate("sword._data is None"))
        #expect(isUnstored)
        try run("sword.quantity = 3")
        let stillDeleted: Int = try #require(try evaluate("len(container.fetch(Item))"))
        #expect(stillDeleted == 0)
        
        // Check reinsert
        try run("container.insert(sword)")
        let reinsertedCount: Int = try #require(try evaluate("len(container.fetch(Item))"))
        #expect(reinsertedCount == 1)
    }

    /// Another device deleting the row, merged by CloudKit under a held model.
    @available(macOS 15, *)
    @Test func changeAfterRemoteDeletionStoresAgain() throws {
        try run("""
        container = Store('remote_delete_testing', True)
        sword = Item(name='Sword')
        container.insert(sword)
        """)
        let container: SwiftPy.Store = try #require(try evaluate("container"))
        let handle: ModelHandle = try #require(try evaluate("sword._data"))
        let row = try #require(try container.row(id: handle.id))
        container.context.delete(row)
        try container.context.save()
        #expect(try container.row(id: handle.id) == nil)

        try run("sword.quantity = 2")

        let restored = try #require(try container.row(id: handle.id))
        #expect(restored.json.contains(#""quantity": 2"#))
        let count: Int = try #require(try evaluate("len(container.fetch(Item))"))
        #expect(count == 1)
    }

    /// Rows written before ids existed get one on their first fetch.
    @available(macOS 15, *)
    @Test func legacyRowsGetAnId() throws {
        try run("container = Store('legacy_testing', True)")
        let container: SwiftPy.Store = try #require(try evaluate("container"))
        let legacy = ModelData(keys: [LookupKeyValue(key: "__name__", value: "Item")], json: #"{"name": "Old"}"#)
        container.context.insert(legacy)

        try run("items = container.fetch(Item)")
        let handle: ModelHandle = try #require(try evaluate("items[0]._data"))
        #expect(legacy.keys?["__id__"] == handle.id)

        try run("items[0].quantity = 5")
        #expect(legacy.json.contains(#""quantity": 5"#))
    }

    @available(macOS 15, *)
    @Test func observeLocalSave() async throws {
        try run("""
        container = Store('observe_local_testing', True)
        seen = []
        observation = container.observe(Item, lambda items: seen.append(len(items)))
        container.insert(Item(name='Sword'))
        """)
        let container: SwiftPy.Store = try #require(try evaluate("container"))
        try container.context.save()
        try await Task.sleep(for: .milliseconds(400))
        let seen: [Int] = try #require(try evaluate("seen"))
        #expect(seen == [1])
    }

    @available(macOS 15, *)
    @Test func observe() async throws {
        try run("""
        container = Store('observe_testing', True)
        seen = []
        observation = container.observe(Item, lambda items: seen.append(len(items)))
        container.insert(Item(name='Sword'))
        """)
        // What the CloudKit mirror posts after merging another device's changes.
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        try await Task.sleep(for: .milliseconds(400))
        let seen: [Int] = try #require(try evaluate("seen"))
        #expect(seen == [1])

        try run("observation.cancel()")
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        try await Task.sleep(for: .milliseconds(400))
        let seenAfterCancel: [Int] = try #require(try evaluate("seen"))
        #expect(seenAfterCancel == [1])
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
