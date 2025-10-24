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

@available(macOS 15, iOS 18, *)
@MainActor
func hookStoragesModule() {
    Interpreter.bindModule("storages", [
        ModelContainer.self,
        ModelData.self,
        LookupKeyValue.self,
    ])
}

// MARK: - Models

@available(macOS 15, iOS 18, *)
@Model
class ModelMetadata {
    var name: String = ""
    var fields: [String: String] = [:]
    var lookupFields: [String] = []

    init(name: String) {
        self.name = name
    }
}

@available(macOS 15, iOS 18, *)
@Scriptable
@Model
class ModelData {
    @Relationship(deleteRule: .cascade, inverse: \LookupKeyValue.model)
    var keys: [LookupKeyValue]?

    @Attribute(.externalStorage)
    var json: String = ""

    var persistentId: Int?

    init(keys: [LookupKeyValue], json: String) {
        self.keys = keys
        self.json = json
    }
}

@available(macOS 15, iOS 18, *)
@Scriptable
@Model
class LookupKeyValue {
    #Index<LookupKeyValue>([\.key], [\.value])

    var key: String = ""
    var value: String = ""
    var model: ModelData?

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

@available(macOS 15, iOS 18, *)
extension [LookupKeyValue] {
    subscript(key: String) -> String? {
        first(where: { $0.key == key })?.value
    }
}

@available(macOS 15, iOS 18, *)
@MainActor
@Scriptable
class ModelContainer: PythonBindable {
    typealias object = PyAPI.Reference
    
    internal let container: SwiftData.ModelContainer
    internal let context: SwiftData.ModelContext
    internal static var inMemoryOnly: Bool = false
    internal static var containers = [ModelContainer]()
    
    init(name: String) throws {
        let schema = Schema([ModelData.self,
                             LookupKeyValue.self,
                             ModelMetadata.self],
                            version: Schema.Version(0, 1, 0))
        
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: Self.inMemoryOnly,
            groupContainer: .automatic,
            cloudKitDatabase: .automatic
        )
        
        container = try SwiftData.ModelContainer(
            for: ModelData.self,
            LookupKeyValue.self,
            ModelMetadata.self,
            configurations: configuration
        )
        
        context = container.mainContext
        
        ModelContainer.containers.append(self)
    }
    
    func insert(model: object) throws {
        // TODO: Update metadata if needed.
        let dataRef = try model.attribute("_data")?.toStack
        guard let modelData = ModelData(dataRef?.reference),
              let keys = modelData.keys,
              let name = keys.first(where: { $0.key == "__name__" })?.value else {
            throw PythonError.ValueError("Invalid model data")
        }
        
        let count = try context.fetchCount(.models(name: name))
        modelData.persistentId = count
        
        context.insert(modelData)
    }
    
    func fetch(_ type: object) throws -> object? {
        let typeName = py_totype(type).name
        let modelsRef = try context.fetch(.models(name: typeName)).toStack
        guard let makeModels = try type.attribute("_makemodels") else {
            throw PythonError.ValueError("Type does not support fetching models")
        }
        return try makeModels.call([modelsRef.reference])
    }

    func delete(model: object) throws {
        let dataRef = try model.attribute("_data")?.toStack
        guard let modelData = ModelData(dataRef?.reference) else {
            throw PythonError.ValueError("Invalid model data")
        }
        context.delete(modelData)
        
        // Recreate the underlying model data for the object so it can be inserted again.
        try model.attribute("_makedata")?.call()
    }
    
    static func inMemory(inMemory: Bool) {
        inMemoryOnly = inMemory
    }
}

@available(macOS 15, iOS 18, *)
extension FetchDescriptor<ModelData> {
    static func models(name: String) -> Self {
        FetchDescriptor(
            predicate: #Predicate { model in
                model.keys.flatMap { keys in
                    keys.contains {
                        $0.key == "__name__" && $0.value == name
                    }
                } ?? true
            },
            sortBy: [SortDescriptor(\.persistentId)]
        )
    }
}
#endif
