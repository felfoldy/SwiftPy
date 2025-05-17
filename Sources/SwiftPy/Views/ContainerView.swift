//
//  ContainerView.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-16.
//

import pocketpy
import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
@MainActor
@Observable
@Scriptable("_View")
class PythonView {
    typealias View = PyAPI.Reference
    
    private let contentType: String

    weak var _parent: PythonView?

    var _subviews: [PythonView] = [] {
        didSet {
            for view in _subviews {
                view._parent = self
            }

            if let ref = _pythonCache.reference {
                try? Self._createBody(content: ref)
            }
        }
    }

    internal var model: ContentModel?
    
    init(contentType: String) {
        self.contentType = contentType
    }
    
    static func _createBody(content: View) throws {
        let view = try PythonView.cast(content)
        let models = view._subviews.compactMap(\.model)
        
        switch view.contentType {
        case "VStack":
            view.model = .vstack(models)
            
        case "ScrollView":
            view.model = .scrollView(models)
            
        case "Table":
            let columnsRef = try content.attribute("columns")?.toStack
            let columns = try [String].cast(columnsRef?.reference)
            
            let rowsRef = try content.attribute("rows")?.toStack
            let rows = try [[String: String]].cast(rowsRef?.reference)
                .map { ContentModel.TableRow(values: $0) }
            
            view.model = .table(keys: columns, rows: rows)

        case "Text":
            let textRef = try content.attribute("text")?.toStack
            let text = try String.cast(textRef?.reference)

            view.model = .text(text)

        default:
            view.model = .empty
        }
    }
    
    static func _makeId() -> String {
        UUID().uuidString
    }
}

@MainActor
@available(macOS 14.4, iOS 17.4, *)
@Observable
@Scriptable("Window")
class PythonWindow {
    typealias View = PythonView
    
    var view: View?
    
    internal var openAction: () -> Void = {}
    
    @ViewBuilder
    internal func makeView() -> some SwiftUI.View {
        view?.model?.body
    }
    
    func open() {
        openAction()
    }
}

@available(macOS 14.4, iOS 17.4, *)
public struct PythonWindows: Scene {
    let name: String
    var content = PythonWindow()

    @Environment(\.openWindow) var openWindow

    public init(name: String = "window") {
        self.name = name
        content.toPython(.main.emplace(name))
        content.openAction = open
    }

    public var body: some Scene {
        WindowGroup(name, id: name) {
            content.makeView()
        }
    }
    
    func open() {
        openWindow(id: name)
    }
}

@available(macOS 14.4, *)
@MainActor
extension PyType {
    static let `View` = PythonView.pyType
}
