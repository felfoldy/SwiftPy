//
//  ViewRepresentation.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-05.
//

import SwiftUI

/// A protocol for types that can provide a SwiftUI-based visual representation of themselves.
///
/// Conform to `ViewRepresentable` when you want your type to render a custom SwiftUI view
/// instead of plain text in interactive or inspection contexts.
///
/// Example:
/// ```swift
/// @Scriptable("Text")
/// final class TextRepresentable: ViewRepresentable {
///     let content: String
///
///     init(content: String) { self.content = content }
///
///     var view: some View {
///         Text(content)
///     }
/// }
/// ```
@MainActor
public protocol ViewRepresentable {
    associatedtype Content: View

    @ViewBuilder var view: Self.Content { get }
}

public extension ViewRepresentable {
    var representation: AnyView {
        AnyView(view)
    }
}

/// Convinient Content view what accesses the Scriptable class itself.
///
/// Example:
/// ```swift
/// @Observable
/// @Scriptable
/// final class CustomView: ViewRepresentable {
///     struct Content: RepresentationContent {
///         @State var model: CustomView
///
///         var body: some View {
///             ...
///         }
///     }
/// }
/// ```
///
/// When class value changes the view will be updated.
public protocol RepresentationContent<Model>: View {
    associatedtype Model
    var model: Model { get set }
    init(model: Model)
}

public extension ViewRepresentable where Content: RepresentationContent, Content.Model == Self {
    var view: Content {
        Content(model: self)
    }
}

extension AnyView: PythonConvertible {
    public func toPython(_ reference: PyRef) {
        py.newobject(self, type: Self.pyType, out: reference, slots: 0)
    }

    public static func fromPython(_ reference: PyRef) -> AnyView {
        if py.typeof(reference) == pyType {
            reference.toUserdata()
        } else {
            reference.view ?? AnyView(erasing: EmptyView())
        }
    }

    public static let pyType = py.newtype(
        name: "AnyView",
        base: .object,
        module: py.getmodule("__main__")
    ) { pointer in
        deinitialize(userdata: pointer)
    }
}
