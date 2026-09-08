//
//  Interpreter+bind.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import PocketPython
import Foundation

extension Interpreter {
    /// Internal module binding.
    func bindModule(_ name: String, docs: String? = nil, block: @escaping (PyModule) -> Void) {
        moduleFactory[name] = { module in
            guard let module = PyModule(module) else { return }

            block(module)
            if let docs {
                module.__doc__ = docs
            }
        }
    }

    func bindModule(_ name: String, in bundle: Bundle) {
        guard let path = bundle.path(forResource: name, ofType: "py"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            log.error("Could not find \(name).py in bundle \(bundle.bundlePath)")
            return
        }

        // Dotted submodules (e.g. "console.session") are requested by the
        // import machinery as a slashed path ("console/session.py").
        let key = name.replacingOccurrences(of: ".", with: "/") + ".py"
        registeredSources[key] = content
    }
}
