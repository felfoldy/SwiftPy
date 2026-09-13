//
//  Interpreter+bindPathlib.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-10.
//

import Foundation

extension Interpreter {
    func bindPathlib() {
        #if cpython
        // The stdlib pathlib, plus the app's own locations as classmethods.
        bindModule("_swiftpy_paths") { module in
            module.def("documents() -> str") { argc, argv in
                PyBind.function(argc, argv) { Path.home().description }
            }
            module.def("resources() -> str") { argc, argv in
                PyBind.function(argc, argv) { try Path.resources().description }
            }
            module.def("tmp() -> str") { argc, argv in
                PyBind.function(argc, argv) { Path.tmp().description }
            }
            module.def("site_packages() -> str") { argc, argv in
                PyBind.function(argc, argv) { try Path.sitePackages().description }
            }
        }
        // Runs in __main__, so everything stays inside one function's scope.
        let patch = """
        def _swiftpy_extend_pathlib():
            import _swiftpy_paths as paths
            from pathlib import Path

            def classmethod_of(location, doc):
                def method(cls): return cls(location())
                method.__doc__ = doc
                return classmethod(method)

            # The sandbox has no use for ~ (the container root); Documents is
            # what the app calls home, and where cwd starts.
            Path.home = classmethod_of(paths.documents, "Documents directory.")
            Path.resources = classmethod_of(paths.resources, "The host bundle's resource directory.")
            Path.tmp = classmethod_of(paths.tmp, "The app's temporary directory. Safe to write scratch files to, but the system may purge its contents at any time.")
            Path.site_packages = classmethod_of(paths.site_packages, "Directory of the installed packages.")

        _swiftpy_extend_pathlib()
        del _swiftpy_extend_pathlib
        """
        do { try py.run(patch) } catch { log.error("pathlib extras failed: \(error)") }
        #else
        bindModule("pathlib", docs: "Object-oriented filesystem paths.") { module in
            module.class(Path.self)
        }
        #endif
    }
}
