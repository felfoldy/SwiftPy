//
//  ButtonSyntax.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-05.
//

import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
public struct ButtonSyntax: ViewSyntax {
    let label: AnyPythonViewSyntax
    let action: () -> Void
    
    public var body: some View {
        Button {
            action()
        } label: {
            label
        }
    }
    
    public static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> ButtonSyntax {
        try ButtonSyntax(
            label: context.anyContent()
        ) {
            _ = try? PyAPI.call(view.attribute("_action"))
        }
    }
    
    nonisolated static public func ==(lhs: ButtonSyntax, rhs: ButtonSyntax) -> Bool {
        MainActor.assumeIsolated {
            lhs.label == rhs.label
        }
    }
    
    nonisolated public func hash(into hasher: inout Hasher) {
        MainActor.assumeIsolated {
            hasher.combine(label)
        }
    }
}
