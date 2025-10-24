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
