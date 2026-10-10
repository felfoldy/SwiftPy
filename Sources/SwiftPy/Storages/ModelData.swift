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

// MARK: - Handle

/// What a model holds instead of its row. The store syncs through CloudKit, so
/// a row can vanish under a merge from another device, and touching a SwiftData
/// instance whose row is gone traps. The handle resolves the row by id on each
/// write instead.
@available(macOS 15, iOS 18, *)
@MainActor
@Scriptable
final class ModelHandle: PythonBindable {
    internal let store: Store
    internal let id: String
    internal let typeName: String
    private var lastJSON: String

    internal init(store: Store, id: String, typeName: String, json: String) {
        self.store = store
        self.id = id
        self.typeName = typeName
        lastJSON = json
    }

    /// The fields as JSON, as last read from or written to the store.
    ///
    /// A write to a row that another device deleted stores it again.
    var json: String {
        get { lastJSON }
        set {
            lastJSON = newValue
            if let row = try? store.row(id: id) {
                row.json = newValue
                store.recordVersion(id: id, json: newValue)
            } else {
                store.insertRow(id: id, typeName: typeName, json: newValue)
            }
        }
    }
}

/// Keeps a ``Store/observe(_:callback:)`` callback registered until cancelled
/// or released.
@available(macOS 15, iOS 18, *)
@MainActor
@Scriptable
final class StoreObservation: PythonBindable {
    internal let type: PyObject
    internal let callback: PyObject
    private weak var store: Store?

    internal init(store: Store, type: PyObject, callback: PyObject) {
        self.store = store
        self.type = type
        self.callback = callback
    }

    /// Stops the callback from being called.
    func cancel() {
        store?.remove(self)
    }
}

// MARK: - Store

/// A persistent collection of instances created with the `modeling.model` decorator.
///
/// Stores are saved between launches by default. Pass `in_memory=True` to create
/// a temporary store whose contents are discarded when the process exits.
///
/// Pass `keep_versions=True` to keep earlier states of each instance, read
/// with ``versions``. They're stored, and synced, with the instances.
@available(macOS 15, iOS 18, *)
@MainActor
@Scriptable
class Store: PythonBindable {
    internal let container: SwiftData.ModelContainer
    internal let context: SwiftData.ModelContext
    internal static var containers = [Store]()

    private struct WeakObservation {
        weak var value: StoreObservation?
    }

    private var observations: [WeakObservation] = []
    private var notificationTokens: [any NSObjectProtocol] = []
    private var refresh: Task<Void, Never>?

    /// Versions live in the store itself, so they sync with its models.
    private let keepsVersions: Bool
    internal var versionContext: SwiftData.ModelContext? { keepsVersions ? context : nil }
    private var pendingVersions: [String: String] = [:]
    private var versionFlush: Task<Void, Never>?
    internal static let versionLimit = 50

    /// Creates a store with the given name.
    ///
    /// name: A stable name identifying the store.
    /// in_memory: Whether the store should keep its contents only in memory. Defaults to False.
    /// keep_versions: Whether to keep earlier states of each instance, synced like the instances. Defaults to False.
    init(name: String, inMemory: Bool = false, keepVersions: Bool = false) throws {
        // Versions are in every store's schema, so opening a store with or
        // without them doesn't migrate it.
        let schema = Schema([ModelData.self,
                             LookupKeyValue.self,
                             ModelMetadata.self,
                             ModelVersionData.self],
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
            ModelVersionData.self,
            configurations: configuration
        )

        context = container.mainContext
        keepsVersions = keepVersions

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

        let id = UUID().uuidString
        insertRow(id: id, typeName: typeName, json: json)
        model._data = ModelHandle(store: self, id: id, typeName: typeName, json: json)
    }

    /// Returns all stored instances of a model type.
    ///
    /// type: A class created with the `model` decorator.
    func fetch(_ type: PyObject) throws -> PyObject? {
        let typeName = py.totype(type.reference).name
        try py.module("storage")?._extend?(type)
        let rows = try context.fetch(.models(name: typeName))
        let handles = rows.map { row in
            ModelHandle(store: self, id: identify(row), typeName: typeName, json: row.json)
        }
        return try type._makemodels?(handles)
    }

    /// Deletes a model instance from the store.
    ///
    /// model: The model instance to delete.
    func delete(model: PyObject) throws {
        guard let handle = ModelHandle(model._data) else {
            throw PythonError.ValueError("Invalid model data")
        }
        if let row = try row(id: handle.id) {
            context.delete(row)
        }
        deleteAllVersions(id: handle.id)
        // Unstored again: a later change must not put it back.
        model._data = Optional<PyObject>.none
    }

    /// Calls back with the stored instances of a model type whenever they
    /// change, from this device or from another one through iCloud.
    ///
    /// type: A class created with the `model` decorator.
    /// callback: Called with the list of instances, the way ``fetch`` returns them.
    ///
    /// Returns an observation; keep it, the callback stops when it is released
    /// or cancelled.
    ///
    /// ```python
    /// observation = store.observe(Item, lambda items: print(len(items)))
    /// ```
    func observe(_ type: PyObject, callback: PyObject) -> StoreObservation {
        let observation = StoreObservation(store: self, type: type, callback: callback)
        observations.append(WeakObservation(value: observation))
        if notificationTokens.isEmpty {
            subscribe()
        }
        return observation
    }

    /// Earlier states of a stored instance, newest first. The first is the
    /// state it holds now.
    ///
    /// model: The stored model instance.
    ///
    /// ```python
    /// store = Store('notes', keep_versions=True)
    /// for version in store.versions(note):
    ///     print(version.date, version.model.text)
    /// ```
    func versions(model: PyObject) throws -> [ModelVersion] {
        guard let versionContext else {
            throw PythonError.ValueError("This store keeps no versions: create it with keep_versions=True.")
        }
        guard let handle = ModelHandle(model._data) else { return [] }
        flushVersions()
        let type = py.typeof(model.reference)
        let typeObject = PyObject(type)
        return try versionContext.fetch(.versions(of: handle.id)).map { version in
            guard let copy: PyObject = try typeObject._from_json?(version.json) else {
                throw PythonError.ValueError("Failed to read a version of \(type.name)")
            }
            return ModelVersion(id: version.versionId, date: version.date.ISO8601Format(), model: copy)
        }
    }

    /// Deletes the versions of a stored instance newer than the given one,
    /// as when going on from an earlier state discards the ones after it.
    ///
    /// model: The stored model instance.
    /// newer_than: The `id` of the version to keep, with the ones before it.
    func deleteVersions(model: PyObject, newerThan: String) throws {
        guard let versionContext else {
            throw PythonError.ValueError("This store keeps no versions: create it with keep_versions=True.")
        }
        guard let handle = ModelHandle(model._data) else { return }
        flushVersions()
        let versions = try versionContext.fetch(.versions(of: handle.id))
        guard let index = versions.firstIndex(where: { $0.versionId == newerThan }) else {
            throw PythonError.ValueError("No version \(newerThan) of this model.")
        }
        for version in versions[..<index] {
            versionContext.delete(version)
        }
        try? versionContext.save()
    }

    internal func remove(_ observation: StoreObservation) {
        observations.removeAll { $0.value == nil || $0.value === observation }
    }

    // MARK: Rows

    internal static let idKey = "__id__"

    internal func row(id: String) throws -> ModelData? {
        let key = Self.idKey
        let descriptor = FetchDescriptor<ModelData>(
            predicate: #Predicate { model in
                model.keys.flatMap { keys in
                    keys.contains { $0.key == key && $0.value == id }
                } ?? false
            }
        )
        return try context.fetch(descriptor).first
    }

    @discardableResult
    internal func insertRow(id: String, typeName: String, json: String) -> ModelData {
        let keys = [
            LookupKeyValue(key: "__name__", value: typeName),
            LookupKeyValue(key: Self.idKey, value: id),
        ]
        let row = ModelData(keys: keys, json: json)
        row.persistentId = (try? context.fetchCount(.models(name: typeName))) ?? 0
        context.insert(row)
        recordVersion(id: id, json: json)
        return row
    }

    // MARK: Versions

    /// A model's setters write once per field, each its own hop from the
    /// interpreter, so the writes within a short window become one version.
    internal func recordVersion(id: String, json: String) {
        guard versionContext != nil else { return }
        pendingVersions[id] = json
        guard versionFlush == nil else { return }
        versionFlush = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            self?.flushVersions()
        }
    }

    internal func flushVersions() {
        versionFlush?.cancel()
        versionFlush = nil
        guard let versionContext, !pendingVersions.isEmpty else { return }
        let pending = pendingVersions
        pendingVersions = [:]
        for (id, json) in pending {
            let saved = (try? versionContext.fetch(.versions(of: id))) ?? []
            if saved.first?.json == json { continue }
            // Another device can number one the same; dates order them.
            let order = (saved.first?.order ?? 0) + 1
            versionContext.insert(ModelVersionData(rowId: id, order: order, json: json))
            for old in saved.dropFirst(Self.versionLimit - 1) {
                versionContext.delete(old)
            }
        }
        // Written a moment after the change, so autosave may not get to them
        // before the app quits.
        try? versionContext.save()
    }

    private func deleteAllVersions(id: String) {
        pendingVersions[id] = nil
        guard let versionContext else { return }
        for version in (try? versionContext.fetch(.versions(of: id))) ?? [] {
            versionContext.delete(version)
        }
    }

    /// The row's id, given to rows written before ids existed.
    private func identify(_ row: ModelData) -> String {
        if let id = row.keys?[Self.idKey] {
            return id
        }
        let id = UUID().uuidString
        row.keys = (row.keys ?? []) + [LookupKeyValue(key: Self.idKey, value: id)]
        return id
    }

    // MARK: Observation

    private func subscribe() {
        let center = NotificationCenter.default
        // The CloudKit mirror posts the first for merges from other devices;
        // the context posts the second for this device's saves.
        let sources: [(Notification.Name, Any?)] = [
            (.NSPersistentStoreRemoteChange, nil),
            (ModelContext.didSave, context),
        ]
        for (name, object) in sources {
            let token = center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRefresh() }
            }
            notificationTokens.append(token)
        }
    }

    /// Merges arrive in bursts, so one refresh follows a short quiet period.
    private func scheduleRefresh() {
        refresh?.cancel()
        refresh = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.refreshObservations()
        }
    }

    private func refreshObservations() {
        observations.removeAll { $0.value == nil }
        for observation in observations.compactMap(\.value) {
            do {
                let models = try fetch(observation.type)
                try observation.callback.throwing(models)
            } catch let error as PythonError {
                Interpreter.shared.report(error)
            } catch {
                Interpreter.shared.report(.RuntimeError(error.localizedDescription))
            }
        }
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
