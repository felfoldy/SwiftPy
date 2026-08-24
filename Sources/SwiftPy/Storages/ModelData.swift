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

/// A persistent collection of instances created with the `modeling.model` decorator.
///
/// Stores are saved between launches by default. Pass `in_memory=True` to create
/// a temporary store whose contents are discarded when the process exits.
@available(macOS 15, iOS 18, *)
@MainActor
@Scriptable
class Store: PythonBindable {    
    internal let container: SwiftData.ModelContainer
    internal let context: SwiftData.ModelContext
    internal static var containers = [Store]()
    
    /// Creates a store with the given name.
    ///
    /// name: A stable name identifying the store.
    /// in_memory: Whether the store should keep its contents only in memory. Defaults to False.
    init(name: String, inMemory: Bool = false) throws {
        let schema = Schema([ModelData.self,
                             LookupKeyValue.self,
                             ModelMetadata.self],
                            version: Schema.Version(0, 1, 0))
        
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: inMemory,
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
        
        Store.containers.append(self)
    }
    
    /// Inserts a model instance into the store.
    ///
    /// model: The model instance to insert.
    func insert(model: PyObject) throws {
        let type = py.typeof(model.reference)
        let typeName = type.name
        let typeObject = PyObject(type)
        
        try py.module("storage")?._extend?(typeObject)

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

    /// Returns all stored instances of a model type.
    ///
    /// type: A class created with the `model` decorator.
    func fetch(_ type: PyObject) throws -> PyObject? {
        let typeName = py.totype(type.reference).name
        try py.module("storage")?._extend?(type)
        let models = try context.fetch(.models(name: typeName))
        let result = try type._makemodels?(models)
        return result
    }

    /// Deletes a model instance from the store.
    ///
    /// model: The model instance to delete.
    func delete(model: PyObject) throws {
        guard let modelData = ModelData(model._data) else {
            throw PythonError.ValueError("Invalid model data")
        }
        context.delete(modelData)
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
