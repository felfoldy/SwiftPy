//
//  ModelVersions.swift
//  SwiftPy
//

#if canImport(SwiftData)
import SwiftData
import Foundation

/// One stored state of a row, kept in the store's device-local versions
/// container. SwiftData history records which attributes changed, not their
/// earlier values, so the states are copied here.
@available(macOS 15, iOS 18, *)
@Model
class ModelVersionData {
    #Index<ModelVersionData>([\.rowId])

    var rowId: String = ""
    var order: Int = 0
    var date: Date = Date.distantPast

    @Attribute(.externalStorage)
    var json: String = ""

    init(rowId: String, order: Int, json: String) {
        self.rowId = rowId
        self.order = order
        self.json = json
        date = .now
    }
}

/// An earlier state of a stored model, from ``Store/versions(model:)``.
@available(macOS 15, iOS 18, *)
@MainActor
@Scriptable
final class ModelVersion: PythonBindable {
    /// When the model held this state, in ISO 8601.
    let date: String

    /// A copy of the model as it was. It isn't stored: insert it to keep it.
    let model: PyObject

    internal init(date: String, model: PyObject) {
        self.date = date
        self.model = model
    }
}

@available(macOS 15, iOS 18, *)
extension FetchDescriptor<ModelVersionData> {
    /// A row's versions, newest first.
    static func versions(of rowId: String) -> Self {
        FetchDescriptor(
            predicate: #Predicate { $0.rowId == rowId },
            sortBy: [SortDescriptor(\.order, order: .reverse)]
        )
    }
}
#endif
