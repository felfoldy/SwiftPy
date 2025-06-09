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
    let action: PyAPI.Reference
    
    public var body: some View {
        Button {
            _ = try? PyAPI.call(action)
        } label: {
            label
        }
    }
    
    public static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> ButtonSyntax {
        try ButtonSyntax(
            label: context.anyContent(),
            action: view.castAttribute("action")
        )
    }
    
    nonisolated static public func ==(lhs: ButtonSyntax, rhs: ButtonSyntax) -> Bool {
        MainActor.assumeIsolated {
            lhs.label == rhs.label && lhs.action == rhs.action
        }
    }
    
    nonisolated public func hash(into hasher: inout Hasher) {
        MainActor.assumeIsolated {
            hasher.combine(label)
            hasher.combine(action)
        }
    }
}
