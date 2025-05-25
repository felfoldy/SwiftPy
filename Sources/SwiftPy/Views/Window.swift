//
//  Window.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-20.
//

import SwiftUI

struct WindowKey: Codable, Hashable {
    let id: String
}

@MainActor
@available(macOS 14.4, iOS 17.4, *)
@Observable
@Scriptable("Window")
class PythonWindow: Identifiable {
    typealias View = PythonView
    
    var view: View?

    internal let id: WindowKey
    
    init(id: String) {
        self.id = WindowKey(id: id)
        PythonWindow.windows[self.id] = self
    }

    func open() {
        PythonWindow.open(id)
    }

    @ViewBuilder
    internal func makeView() -> some SwiftUI.View {
        if let model = view?.syntax {
            AnyView(model)
        } else {
            EmptyView()
        }
    }
    
    static func makeIfNeeded(_ id: String) -> PythonWindow {
        if let window = PythonWindow.windows[WindowKey(id: id)] {
            window
        } else {
            PythonWindow(id: id)
        }
    }

    internal static var open: (WindowKey) -> Void = { _ in }
    internal static var windows = [WindowKey: PythonWindow]()
}

@available(macOS 14.4, iOS 17.4, *)
public struct PythonWindows: Scene {
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow

    public init() {
        PythonWindow.open = open(key:)
    }

    public var body: some Scene {
        WindowGroup(for: PythonWindow.ID.self) { $key in
            if let key {
                if let window = PythonWindow.windows[key] {
                    window.makeView()
                } else {
                    EmptyView().onAppear {
                        dismissWindow(value: key)
                    }
                }
            }
        }
    }
    
    func open(key: WindowKey) {
        openWindow(value: key)
    }
}
