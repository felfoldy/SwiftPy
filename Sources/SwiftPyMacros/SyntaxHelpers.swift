//
//  SyntaxHelpers.swift
//  SwiftPy
//

import SwiftSyntax
import SwiftSyntaxMacros

extension ClassDeclSyntax {
    func inherits(from typeName: String) -> Bool {
        inheritanceClause?.inheritedTypes
            .compactMap { $0.type.as(IdentifierTypeSyntax.self) }
            .map(\.name.text)
            .contains(typeName) ?? false
    }
}

extension DeclModifierListSyntax {
    var isVisibleForPython: Bool {
        !contains {
            $0.name.text == "internal" || $0.name.text == "private"
        }
    }

    var isStatic: Bool {
        contains {
            $0.name.text == "static"
        }
    }

    var publicVisibility: String {
        map(\.name.text)
            .map { $0 + " " }
            .first { $0.contains("public") } ?? ""
    }
}

// MARK: - Diagnostics

extension MacroExpansionContext {
    func warning(_ node: any SyntaxProtocol, _ message: String) {
        let msg = MacroExpansionWarningMessage(message)
        diagnose(.init(node: node, message: msg))
    }
}
