//
//  CPythonSourceImporter.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-11.
//

#if cpython
extension Interpreter {
    /// Lets `import` reach the Python sources registered from Swift, the way
    /// pocketpy's importfile callback does. The finder itself is the cpython
    /// package's: it answers on the importing thread, under the import lock,
    /// which is why nothing here may touch the main actor.
    func installSourceImporter() {
        PyRuntime.sourceProvider = { name in Interpreter.source(name: name) }
        PyRuntime.packageProvider = { name in
            // A package is whatever has a submodule registered under it.
            let prefix = name.replacingOccurrences(of: ".", with: "/") + "/"
            return Interpreter.registeredSources.names.contains { $0.hasPrefix(prefix) }
        }
        do {
            try PyRuntime.installSourceFinder()
        } catch {
            log.error("could not install the Swift source importer: \(error)")
        }
    }
}
#endif
