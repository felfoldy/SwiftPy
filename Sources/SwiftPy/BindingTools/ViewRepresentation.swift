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
    var representation: ViewRepresentation {
        ViewRepresentation { view }
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

/// A type ereased wrapper for a SwiftUI view to store in python.
///
/// See also:
/// - ``ViewRepresentable``
@Scriptable
public final class ViewRepresentation {
    @usableFromInline
    internal let anyView: AnyView

    private init(view: AnyView) {
        anyView = view
    }
}

public extension ViewRepresentation {
    convenience init<Content: View>(@ViewBuilder content: () -> Content) {
        self.init(view: AnyView(content()))
    }

    @inlinable
    var view: AnyView { anyView }
}

#Preview {
    ViewRepresentation {
        Text("View")
    }
    .view
    .padding()
}
