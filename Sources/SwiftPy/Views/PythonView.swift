//
//  ContainerView.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-16.
//

import pocketpy
import SwiftUI

@available(macOS 14.4, iOS 17.4, *)
public struct PythonViewContext {
    var subviews: [any ViewSyntax]
    
    public func anyContent() throws -> AnyPythonViewSyntax {
        guard let content = subviews.first else {
            throw PythonError.RuntimeError("Modified content is missing")
        }
        return AnyPythonViewSyntax(syntax: content)
    }
    
    public func anySubviews() -> [AnyPythonViewSyntax] {
        subviews.map(AnyPythonViewSyntax.init)
    }
}

@available(macOS 14.4, iOS 17.4, visionOS 1.1, *)
@MainActor
@Observable
@Scriptable("_View")
public class PythonView {
    typealias View = PyAPI.Reference

    var _isConfigured: Bool = false
    weak var _parent: PythonView?

    var _subviews: [PythonView] = [] {
        didSet {
            for view in _subviews {
                view._parent = self
            }

            guard _isConfigured else { return }

            let ref = toStack

            if let reference = ref.reference {
                try? Self._buildSyntax(view: reference)
            }
        }
    }

    internal let contentType: String
    internal var syntax: (any ViewSyntax)?
    
    init(contentType: String) {
        self.contentType = contentType
    }
    
    func _config() {
        _isConfigured = true
        if let ref = _pythonCache.reference {
            try? Self._buildSyntax(view: ref)
        }
    }
    
    static func _buildSyntax(view: View) throws {
        let pythonView = try PythonView.cast(view)
        
        let syntax = ViewSyntaxBuilder
            .resolver[pythonView.contentType]
        
        let context = PythonViewContext(
            subviews: pythonView._subviews.compactMap(\.syntax)
        )
        
        pythonView.syntax = try syntax?
            .build(view: view, context: context)
    }
    
    static func _makeId() -> String {
        UUID().uuidString
    }
    
    // MARK: - Codable
    
    private enum CodingKeys : String, CodingKey {
        case _isConfigured
        case _parent
        case _subviews
        case contentType
    }
}

@available(macOS 14.4, iOS 17.4, *)
extension PythonView: @preconcurrency CustomStringConvertible {
    public var view: AnyPythonViewSyntax? {
        if let syntax {
            return AnyPythonViewSyntax(syntax: syntax)
        }
        return nil
    }
    
    public var description: String {
        if let syntax {
            return String(describing: syntax)
        } else {
            return "Uninitialized View"
        }
    }
}
