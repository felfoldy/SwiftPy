//
//  CPythonSourceImporter.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-11.
//

#if cpython
extension Interpreter {
    /// Lets `import` reach the Python sources registered from Swift, the way
    /// pocketpy's importfile callback does. Appended to `sys.meta_path`, so
    /// the bundled stdlib wins and Swift sources only fill the gaps.
    func installSourceImporter() {
        bindModule("_swiftpy_sources") { module in
            module.def("source(name: str) -> str | None") { argc, argv in
                PyBind.function(argc, argv) { (name: String) -> String? in
                    Interpreter.source(name: name)
                }
            }

            module.def("is_package(name: str) -> bool") { argc, argv in
                PyBind.function(argc, argv) { (name: String) -> Bool in
                    // A package is whatever has a submodule registered under it.
                    let prefix = name.replacingOccurrences(of: ".", with: "/") + "/"
                    return Interpreter.shared.registeredSources.keys
                        .contains { $0.hasPrefix(prefix) }
                }
            }
        }

        // A namespace of its own, not __main__: the console clears that.
        guard let namespace = try? PyRuntime.namespace(),
              let code = try? PythonCompiler.compile(Self.finderSource, filename: "<_swiftpy_sources>") else {
            log.error("could not install the Swift source importer")
            return
        }
        _ = try? PyRuntime.execute(code, globals: namespace)
    }

    private static let finderSource = """
    import sys
    from _frozen_importlib import ModuleSpec
    import _swiftpy_sources as _sources

    class _SwiftSourceLoader:
        def __init__(self, source):
            self._source = source

        def create_module(self, spec):
            return None

        def exec_module(self, module):
            code = compile(self._source, module.__spec__.origin, 'exec')
            exec(code, module.__dict__)

        # What tracebacks and linecache read the lines from.
        def get_source(self, fullname):
            return self._source

    class _SwiftSourceFinder:
        @staticmethod
        def find_spec(fullname, path=None, target=None):
            source = _sources.source(fullname)
            if source is None:
                return None
            spec = ModuleSpec(fullname, _SwiftSourceLoader(source), origin='<' + fullname + '>')
            if _sources.is_package(fullname):
                spec.submodule_search_locations = []
            return spec

    sys.meta_path.append(_SwiftSourceFinder)
    """
}
#endif
