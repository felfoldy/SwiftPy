//
//  FontModifierSyntax.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-20.
//

import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
struct FontModifierSyntax: ViewSyntax {
    let content: AnyPythonViewSyntax
    let style: String

    var body: some View {
        content
            .font(.system(
                textStyle(),
                design: .default,
                weight: .none
            ))
    }
    
    func textStyle() -> Font.TextStyle {
        switch style {
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
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> FontModifierSyntax {
        try FontModifierSyntax(
            content: context.anyContent(),
            style: view.castAttribute("font")
        )
    }
}
