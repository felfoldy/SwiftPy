//
//  InteractableModifier.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-23.
//

#if canImport(SwiftUI)
import SwiftUI
import pocketpy

struct InteractableModifier: ViewModifier {
    let name: String
    let object: AnyObject
    
    private let main = Interpreter.main
    @Environment(\.viewContext) private var viewContext
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let convertible = object as? PythonConvertible else {
                    return
                }

                viewContext?.setAttribute(name, py_None())
                convertible.toPython(viewContext?[name])
            }
            .onDisappear {
                viewContext?.deleteAttribute(name)
            }
    }
}

public extension View {
    func interactable(_ name: String, _ object: AnyObject) -> some View {
        modifier(InteractableModifier(name: name, object: object))
    }
}
#endif
