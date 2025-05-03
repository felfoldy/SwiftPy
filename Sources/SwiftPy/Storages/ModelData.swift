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

@MainActor
extension PyAPI.Reference {
    static let storages = Interpreter.module("storages")!
}

// MARK: - Models

@available(macOS 15, iOS 18, *)
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

@available(macOS 15, iOS 18, *)
@Scriptable(module: .storages)
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

@available(macOS 15, iOS 18, *)
@Model
class LookupKey {
    #Index<LookupKey>([\.key], [\.value])
    
    var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public extension Interpreter {
    static func initStorages() {
        if #available(macOS 15, *) {
            _ = ModelContainer.pyType
            _ = ModelData.pyType
        }
    }
}

@available(macOS 15, iOS 18, *)
@MainActor
@Scriptable(module: .storages)
class ModelContainer {
    typealias object = PyAPI.Reference
    
    internal let container: SwiftData.ModelContainer
    internal let context: SwiftData.ModelContext
    
    init(name: String) throws {
        
        let schema = Schema([ModelData.self,
                             LookupKey.self,
                             ModelMetadata.self],
                            version: Schema.Version(0, 1, 0))
        
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: true,
            groupContainer: .automatic,
            cloudKitDatabase: .automatic
        )
        
        container = try SwiftData.ModelContainer(
            for: ModelData.self,
            LookupKey.self,
            ModelMetadata.self,
            configurations: configuration
        )
        
        context = container.mainContext
    }
    
    func insert(model: object) throws {
        // TODO: Update metadata if needed.
        let dataRef = try model.attribute("_data")?.toStack
        guard let modelData = ModelData(dataRef?.reference) else {
            throw PythonError.ValueError("Invalid model data")
        }
        context.insert(modelData)
    }
    
    func fetch(_ type: object) throws -> [object] {
        let type = py_totype(type)
        let name = type.name
        let descriptor = FetchDescriptor<ModelData>(
            predicate: #Predicate { model in
                model.keys.contains(where: {
                    $0.key == "__name__" && $0.value == name
                })
            }
        )
        
        let models = try context.fetch(descriptor)
        _ = models.map(\.json)
        // TODO: Reconstruct models from json.

        return []
    }
    
    func delete(model: object) throws {
        
    }
}
#endif
