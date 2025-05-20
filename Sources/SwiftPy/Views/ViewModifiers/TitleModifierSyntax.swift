//
//  TitleModifierSyntax.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-21.
//

import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
struct TitleModifierSyntax: ViewSyntax {
    let content: AnyPythonViewSyntax
    let title: String
    
    var body: some View {
        content.navigationTitle(title)
    }
    
    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> TitleModifierSyntax {
        try TitleModifierSyntax(
            content: context.anyContent(),
            title: try view.castAttribute("title")
        )
    }
}
