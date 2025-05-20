//
//  ViewSyntax.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-17.
//

import SwiftUI

@MainActor
@available(macOS 14.4, iOS 17.4, *)
public struct ViewSyntaxBuilder {
    static var resolver: [String: any ViewSyntax.Type] = [
        "Text": TextSyntax.self,
        "SystemImage": SystemImageSyntax.self,
        "VStack": VStackSyntax.self,
        "ScrollView": ScrollViewSyntax.self,
        "Table": TableSyntax.self,
        
        // Modifiers
        "FontModifier": FontModifierSyntax.self,
        "ForegroundModifier": ForegroundModifierSyntax.self,
        "TitleModifier": TitleModifierSyntax.self,
    ]
}

public protocol ViewSyntaxBase: Hashable, Identifiable, Equatable, View, Sendable {}

@available(macOS 14.4, iOS 17.4, *)
extension ViewSyntaxBase {
    nonisolated public var id: Self { self }
}

@available(macOS 14.4, iOS 17.4, *)
public protocol ViewSyntax: ViewSyntaxBase {
    static func build(view: PyAPI.Reference,
                      context: PythonViewContext) throws -> Self
}

@available(macOS 14.4, iOS 17.4, *)
public struct AnyPythonViewSyntax: ViewSyntaxBase, @preconcurrency CustomStringConvertible {
    let syntax: any ViewSyntax
    
    public var body: some View {
        AnyView(syntax)
    }
    
    public var description: String {
        String(describing: syntax)
    }
    
    nonisolated public static func ==(
        lhs: AnyPythonViewSyntax,
        rhs: AnyPythonViewSyntax
    ) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(syntax)
    }
}

@available(macOS 14.4, iOS 17.4, *)
struct VStackSyntax: ViewSyntax {
    let contents: [AnyPythonViewSyntax]
    
    var body: some View {
        VStack {
            ForEach(contents) { content in
                content
            }
        }
    }
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> VStackSyntax {
        VStackSyntax(
            contents: context.subviews
                .map(AnyPythonViewSyntax.init)
        )
    }
}

@available(macOS 14.4, iOS 17.4, *)
struct ScrollViewSyntax: ViewSyntax {
    let contents: [AnyPythonViewSyntax]
    
    var body: some View {
        ScrollView {
            ForEach(contents) { content in
                content
            }
        }
    }
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> ScrollViewSyntax {
        ScrollViewSyntax(contents: context.anySubviews())
    }
}

@available(macOS 14.4, iOS 17.4, *)
struct TextSyntax: ViewSyntax {
    let text: String
    
    var body: some View {
        Text(text)
    }
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> TextSyntax {
        try TextSyntax(text: view.castAttribute("text"))
    }
}

@available(macOS 14.4, iOS 17.4, *)
struct SystemImageSyntax: ViewSyntax {
    let name: String
    
    var body: some View {
        Image(systemName: name)
    }
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> SystemImageSyntax {
        try SystemImageSyntax(name: view.castAttribute("name"))
    }
}

@available(macOS 14.4, iOS 17.4, *)
struct TableSyntax: ViewSyntax {
    struct TableRow: Hashable, Identifiable {
        let id = UUID()
        let values: [String: String]
    }
    
    let columns: [String]
    let rows: [TableRow]
    
    var body: some View {
        Table(rows) {
            TableColumnForEach(columns) { column in
                TableColumn(column) { row in
                    Text(row.values[column] ?? "")
                }
            }
        }
    }
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> TableSyntax {
        let rows: [[String: String]] = try view.castAttribute("rows")

        return try TableSyntax(
            columns: view.castAttribute("columns"),
            rows: rows.map { TableRow(values: $0) }
        )
    }
}

extension String: @retroactive Identifiable {
    public var id: Self { self }
}
