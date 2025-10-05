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
/// instead of plain text in interactive or inspection contexts (for example, when a Python
/// `__repr__()` is evaluated).
///
/// Conforming types supply a `ViewRepresentation`, which is a lightweight wrapper around
/// a SwiftUI view.
///
/// How to conform:
/// - Implement the `representation` computed property and return a `ViewRepresentation`.
/// - Build the representation from any SwiftUI `View`.
///
/// Example:
/// ```swift
/// @Scriptable("Text")
/// final class TextRepresentable: ViewRepresentable {
///     let content: String
///
///     var representation: ViewRepresentation {
///         ViewRepresentation {
///             Text(content)
///                 .font(.headline)
///                 .foregroundStyle(.primary)
///         }
///     }
///
///     init(content: String) { self.content = content }
/// }
/// ```
///
/// See also:
/// - ``ViewRepresentation``
///
/// Requirements:
/// - ``representation``: A `ViewRepresentation` that visually describes the instance.
@MainActor
public protocol ViewRepresentable {
    var representation: ViewRepresentation { get }
}

/// A lightweight wrapper for a SwiftUI view used to visually represent scriptable objects.
///
/// ViewRepresentation lets types provide a custom SwiftUI view (instead of plain text)
/// when they are inspected in interactive contexts, such as when Python `__repr__()`
/// is evaluated.
///
/// How to use:
/// - Conform your type to ``ViewRepresentable``.
/// - Return a `ViewRepresentation` built from any SwiftUI view using a `@ViewBuilder` closure.
///
/// Example:
/// ```swift
/// @Scriptable("Text")
/// final class TextRepresentable: ViewRepresentable {
///     let content: String
///
///     var representation: ViewRepresentation {
///         ViewRepresentation {
///             Text(content)
///         }
///     }
///
///     init(content: String) { self.content = content }
/// }
/// ```
///
/// See also:
/// - ``ViewRepresentable``
@Scriptable
public final class ViewRepresentation {
    internal let view: AnyView

    internal init(view: AnyView) {
        self.view = view
    }
}

public extension ViewRepresentation {
    convenience init<Content: View>(@ViewBuilder content: () -> Content) {
        self.init(view: AnyView(content()))
    }
}

#Preview {
    ViewRepresentation {
        Text("View")
    }
    .view
    .padding()
}
