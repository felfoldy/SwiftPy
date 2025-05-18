//
//  ContentModel.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-17.
//

import SwiftUI


@available(macOS 14.4, iOS 17.4, *)
indirect enum ContentModel: Hashable, Identifiable {
    case vstack([ContentModel])
    case scrollView([ContentModel])
    case table(keys: [String], rows: [TableRow])
    case systemImage(String)
    case text(String)
    case fontModifier(String, content: ContentModel)
    case empty
    
    var id: Self { self }
}

@available(macOS 14.4, iOS 17.4, *)
@MainActor
extension ContentModel: View {
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
            
        case let .fontModifier(_, content):
            AnyView(content.body)
                .font(.title)

        case let .systemImage(name):
            Image(systemName: name)

        case .empty:
            EmptyView()
        }
    }
    
    func subviews(_ contents: [ContentModel]) -> some View {
        ForEach(contents) { content in
            AnyView(content.body)
        }
    }
}

@available(macOS 14.4, iOS 17.4, *)
extension ContentModel {
    struct TableRow: Hashable, Identifiable {
        let id = UUID()
        let values: [String: String]
    }
}
