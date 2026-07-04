//
//  ModelData.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-25.
//

#if canImport(SwiftData)
import SwiftData
import Foundation

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
    typealias object = PyRef
    
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
    
    func insert(model: PyObject) throws {
        let type = py.typeof(model.reference)
        let typeName = type.name
        let typeObject = PyObject(type)
        
        try py.module("storages")?._extend?(typeObject)

        guard let json: String = try py.module("json")?.dumps?(model._fields) else {
            throw PythonError.ValueError("Failed to serialize model fields")
        }

        let nameKey = LookupKeyValue(key: "__name__", value: typeName)
        let modelData = ModelData(keys: [nameKey], json: json)

        let count = try context.fetchCount(.models(name: typeName))
        modelData.persistentId = count

        model._data = modelData

        context.insert(modelData)
    }

    func fetch(_ type: PyObject) throws -> PyObject? {
        let typeName = py.totype(type.reference).name
        try py.module("storages")?._extend?(type)
        let models = try context.fetch(.models(name: typeName))
        let result = try type._makemodels?(models)
        return result
    }

    func delete(model: PyObject) throws {
        guard let modelData = ModelData(model._data) else {
            throw PythonError.ValueError("Invalid model data")
        }
        context.delete(modelData)
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
