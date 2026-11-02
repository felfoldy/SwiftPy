//
//  Interpreter+bind.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import Foundation

extension Interpreter {
    /// Internal module binding.
    func bindModule(_ name: String, docs: String? = nil, block: @escaping (PyModule) -> Void) {
        registeredNativeModules.insert(name)
#if cpython
        // Made at startup rather than on import: the lazy-import hook is
        // pocketpy's, and CPython has no equivalent bound yet.
        guard let module = py.newmodule(name) else { return }
        block(module)
        if let docs {
            module.__doc__ = docs
        }
#else
        moduleFactory[name] = { module in
            guard let module = PyModule(module) else { return }

            block(module)
            if let docs {
                module.__doc__ = docs
            }
        }
#endif
    }

    func bindModule(_ name: String, in bundle: Bundle) {
        guard let path = bundle.path(forResource: name, ofType: "py"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            log.error("Could not find \(name).py in bundle \(bundle.bundlePath)")
            return
        }

        // Dotted submodules (e.g. "console.notebook") are requested by the
        // import machinery as a slashed path ("console/notebook.py").
        let key = name.replacingOccurrences(of: ".", with: "/") + ".py"
        Self.registeredSources.register(content, as: key)
    }
}
