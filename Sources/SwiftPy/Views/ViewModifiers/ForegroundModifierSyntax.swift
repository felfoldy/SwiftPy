//
//  ForegroundModifierSyntax.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-18.
//

import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
struct ForegroundModifierSyntax: ViewSyntax {
    let content: AnyPythonViewSyntax
    let style: String
    
    var body: some View {
        content.foregroundStyle(foregroundStyle)
    }
    
    var foregroundStyle: AnyShapeStyle {
        let color: Color? = switch style {
        case "red": .red
        case "orange": .orange
        case "yellow":  .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        case "white": .white
        case "gray": .gray
        case "black": .black
        case "clear": .clear
        default: nil
        }
        
        if let color {
            return AnyShapeStyle(color)
        }
        
        return AnyShapeStyle(.primary)
    }
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> ForegroundModifierSyntax {
        try ForegroundModifierSyntax(
            content: context.anyContent(),
            style: view.castAttribute("style")
        )
    }
}
