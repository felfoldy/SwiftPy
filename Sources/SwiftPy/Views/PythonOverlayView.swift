//
//  PythonOverlayView.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-10.
//

import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
@Observable
@Scriptable
class OverlayViewContext {
   
    typealias View = PythonView

    var view: View?
}

@available(macOS 14.4, iOS 17.4, *)
public struct PythonOverlayViewModifier: ViewModifier {
    let name: String
    let base: PyAPI.Reference
    @State var context = OverlayViewContext()

    public func body(content: Content) -> some View {
        content
            .onAppear {
                context.toPython(base.emplace(name))
            }
            .onDisappear {
                base.deleteAttribute(name)
            }
            .overlay {
                if let view = context.view?.syntax {
                    AnyView(view)
                }
            }
    }
}

@available(macOS 14.4, iOS 17.4, *)
public extension View {
    func pythonOverlay(_ name: any StringProtocol, on reference: PyAPI.Reference? = nil) -> some View {
        let ref = reference ?? .main
        return modifier(PythonOverlayViewModifier(name: String(name), base: ref))
    }
}
