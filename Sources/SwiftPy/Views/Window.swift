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
        EnvironmentValues().openWindow(value: id)
    }

    @ViewBuilder
    internal func makeView() -> some SwiftUI.View {
        if let model = view?.syntax {
            AnyView(model)
        } else {
            EmptyView()
        }
    }
    
    static func openUrl(url: String) throws {
        guard let url = URL(string: url) else {
            throw PythonError.ValueError("Invalid URL: \(url)")
        }
        EnvironmentValues().openURL(url)
    }

    static func create(_ id: String) -> PythonWindow {
        if let window = PythonWindow.windows[WindowKey(id: id)] {
            window
        } else {
            PythonWindow(id: id)
        }
    }

    internal static var windows = [WindowKey: PythonWindow]()
}

@available(macOS 14.4, iOS 17.4, *)
public struct PythonWindows: Scene {
    @Environment(\.dismissWindow) var dismissWindow

    public init() {}
    
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
}
