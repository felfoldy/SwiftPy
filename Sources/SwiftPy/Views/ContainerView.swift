//
//  ContainerView.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-16.
//

import pocketpy
import SwiftUI

enum ContentModel: Hashable, Identifiable {
    case vstack([ContentModel])
    case text(String)
    case empty
    
    var id: Self { self }
}

@available(macOS 14.0, *)
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
        
        switch view.contentType {
        case "VStack":
            let models = view._subviews.compactMap(\.model)
            view.model = .vstack(models)

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
@available(macOS 14.0, *)
@Observable
@Scriptable("Window")
class PythonWindow {
    typealias View = PythonView
    
    var view: View?
    
    internal var openAction: () -> Void = {}
    
    @ViewBuilder
    internal func makeView() -> some SwiftUI.View {
        if let view = view?.model?.makeView() {
            view
        }
    }
    
    func open() {
        openAction()
    }
}

@available(macOS 14.0, *)
public struct ScriptableWindow: Scene {
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

extension ContentModel {
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case let .vstack(contents):
            VStack {
                ForEach(contents) { content in
                    AnyView(content.makeView())
                }
            }
        case let .text(text):
            Text(text)

        case .empty:
            EmptyView()
        }
    }
}

@available(macOS 14.0, *)
@MainActor
extension PyType {
    static let `View` = PythonView.pyType
}
