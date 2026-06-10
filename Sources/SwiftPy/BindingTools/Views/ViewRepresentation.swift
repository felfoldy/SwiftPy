//
//  ViewRepresentation.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-05.
//

import SwiftUI

@available(*, deprecated, message: "Use @Scriptable(base: .View) and func body() -> AnyView")
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
