//
//  ViewSyntax.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-17.
//

import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
indirect enum ViewSyntax: Hashable, Identifiable {
    case vstack([ViewSyntax])
    case scrollView([ViewSyntax])
    case table(keys: [String], rows: [TableRow])
    case systemImage(String)
    case text(String)
    case fontModifier(String, content: ViewSyntax)
    case empty
    
    var id: Self { self }
}

@available(macOS 14.4, iOS 17.4, *)
@MainActor
extension ViewSyntax: View {
    var body: some View {
        switch self {
        case let .vstack(contents):
            VStack { subviews(contents) }
            
        case let .scrollView(contents):
            ScrollView { subviews(contents) }
            
        case let .table(keys, rows):
            Table(rows) {
                TableColumnForEach(keys, id: \.self) { key in
                    TableColumn(key) { row in
                        if let value = row.values[keys[0]] {
                            Text(value)
                        }
                    }
                }
            }
            
        case let .text(text):
            Text(text)
            
        case let .fontModifier(styleName, content):
            AnyView(content.body)
                .font(.system(.textStyle(styleName)))
            
        case let .systemImage(name):
            Image(systemName: name)
            
        case .empty:
            EmptyView()
        }
    }
    
    func subviews(_ contents: [ViewSyntax]) -> some View {
        ForEach(contents) { content in
            AnyView(content.body)
        }
    }
}

@available(macOS 14.4, iOS 17.4, *)
extension ViewSyntax {
    struct TableRow: Hashable, Identifiable {
        let id = UUID()
        let values: [String: String]
    }
}

@available(macOS 14.4, iOS 17.4, *)
extension PythonView {
    static func generateModel(content: View) throws {
        let view = try PythonView.cast(content)
        let models = view._subviews.compactMap(\.model)
        
        switch view.contentType {
        case "VStack":
            view.model = .vstack(models)
            
        case "ScrollView":
            view.model = .scrollView(models)
            
        case "Table":
            let columnsRef = try content.attribute("columns")?.toStack
            let columns = try [String].cast(columnsRef?.reference)
            
            let rowsRef = try content.attribute("rows")?.toStack
            let rows = try [[String: String]].cast(rowsRef?.reference)
                .map { ViewSyntax.TableRow(values: $0) }
            
            view.model = .table(keys: columns, rows: rows)
            
        case "SystemImage":
            let systemNameRef = try content.self.attribute("name")?.toStack
            let systemName = try String.cast(systemNameRef?.reference)
            
            view.model = .systemImage(systemName)
            
        case "FontModifier":
            let fontRef = try content.attribute("font")?.toStack
            let fontName = try String.cast(fontRef?.reference)
            
            if let modified = view._modifiedView?.model {
                view.model = .fontModifier(fontName, content: modified)
            }
            
        case "Text":
            let textRef = try content.attribute("text")?.toStack
            let text = try String.cast(textRef?.reference)
            
            view.model = .text(text)
            
        default:
            view.model = .empty
        }
    }
}

extension Font.TextStyle {
    static func textStyle(_ name: String) -> Font.TextStyle {
        switch name {
        case "large_title": .largeTitle
        case "title": .title
        case "title2": .title2
        case "title3": .title3
        case "headline": .headline
        case "subheadline": .subheadline
        case "body": .body
        case "callout": .callout
        case "footnote": .footnote
        case "caption": .caption
        case "caption2": .caption2
        default: .body
        }
    }
}
