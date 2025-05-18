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

    var _isConfigured: Bool = false
    weak var _parent: PythonView?
    var _modifiedView: PythonView?

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

    internal let contentType: String
    internal var model: ViewSyntax?
    
    init(contentType: String) {
        self.contentType = contentType
    }
    
    func _config() {
        _isConfigured = true
        if let ref = _pythonCache.reference {
            try? Self._createBody(content: ref)
        }
    }
    
    static func _createBody(content: View) throws {
        try generateModel(content: content)
    }
    
    static func _makeId() -> String {
        UUID().uuidString
    }
}

@available(macOS 14.4, iOS 17.4, *)
extension PythonView: @preconcurrency CustomStringConvertible {
    var description: String {
        if let model {
            return String(describing: model.body)
        } else {
            return "Uninitialized View"
        }
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
