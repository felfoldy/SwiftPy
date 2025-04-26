//
//  ModelData.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-25.
//

#if canImport(SwiftData)
import SwiftData
import Foundation
import pocketpy

// MARK: - Models

@available(macOS 14, iOS 17, *)
@Model
class ModelMetadata {
    @Attribute(.unique)
    var name: String
    var fields: [String: String] = [:]
    var lookupFields: [String] = []

    init(name: String) {
        self.name = name
    }
}

@available(macOS 14, iOS 17, *)
@Model
class ModelData {
    @Relationship
    var keys: [LookupKey]

    @Attribute(.externalStorage)
    var json: String
    
    init(keys: [LookupKey], json: String) {
        self.keys = keys
        self.json = json
    }
}

@available(macOS 14, iOS 17, *)
@Model
class LookupKey {
    @Attribute(.unique)
    var key: String

    init(key: String, value: String) {
        self.key = "\(key):\(value)"
    }
}

@available(macOS 14, iOS 17, *)
@MainActor
class ModelContext {
    typealias PythonObject = PyAPI.Reference
    
    private let container: ModelContainer
    private let context: SwiftData.ModelContext
    
    init(name: String) throws {
        let schema = Schema([ModelData.self,
                             LookupKey.self,
                             ModelMetadata.self],
                            version: Schema.Version(0, 1, 0))
        
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .automatic,
            cloudKitDatabase: .automatic
        )
        
        container = try ModelContainer(
            configurations: configuration
        )
        
        context = container.mainContext
    }
    
    func insert(model: PythonObject) {
        let type = py_typeof(model)
        _ = type.name
        // TODO: asdict(obj) -> dict:
    }
    
    func fetch(type: PythonObject) throws -> [PythonObject] {
        let type = py_totype(type)
        let name = type.name
        
        let descriptor = FetchDescriptor<ModelData>(
            predicate: #Predicate { model in
                model.keys.contains(where: {
                    $0.key == "__name__:\(name)"
                })
            }
        )
        
        let models = try context.fetch(descriptor)
        _ = models.map(\.json)
        // TODO: Reconstruct models from json.

        return []
    }
}
#endif
