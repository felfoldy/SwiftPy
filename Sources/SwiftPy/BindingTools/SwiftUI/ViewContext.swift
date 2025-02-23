//
//  ViewContext.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-23.
//

#if canImport(SwiftUI)
import SwiftUI

@MainActor
struct ViewContextEnvironmentKey: @preconcurrency EnvironmentKey {
    static let defaultValue: PyAPI.Reference? = {
        Interpreter.run("""
        class ViewContext:
            ...
        
        viewcontext = ViewContext()
        """)
        return Interpreter.main["viewcontext"]
    }()
}

extension EnvironmentValues {
    var viewContext: PyAPI.Reference? {
        get { self[ViewContextEnvironmentKey.self] }
        set { self[ViewContextEnvironmentKey.self] = newValue }
    }
}
#endif
