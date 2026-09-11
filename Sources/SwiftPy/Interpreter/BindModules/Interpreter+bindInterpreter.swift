//
//  Interpreter+bindInterpreter.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-11.
//

import Foundation

extension Interpreter {
    func bindInterpreter() {
        bindModule("interpreter.native") { module in
            module.def("host(name: str) -> None",
                       docstring: "Hosts the remote Python interpreter on this device.") { argc, argv in
                PyBind.function(argc, argv) { (name: String) in
                    Interpreter.host(name: name)
                }
            }

            module.def("modules() -> list[str]",
                       docstring: "Return the names of registered Python modules.") { argc, argv in
                PyBind.function(argc, argv) {
                    Interpreter.shared.registeredModuleNames
                }
            }

            module.def("source(name: str) -> str | None",
                       docstring: "Return the Python source of a module, or None when it has none.") { argc, argv in
                PyBind.function(argc, argv) { (name: String) -> String? in
                    Interpreter.source(name: name)
                }
            }

            module.def("display(view) -> None",
                       docstring: "Presents a view in the console. A dict or list is presented as pretty printed JSON.") { argc, argv in
                PyBind.function(argc, argv) { (view: PyObject) -> Void in
                    guard let view = view.reference.displayView else { return }
                    Interpreter.interface.display(view)
                }
            }

            module.def("set_timeout(milliseconds: int | None) -> None",
                       docstring: "Sets the execution timeout, or None to disable it.") { argc, argv in
                PyBind.function(argc, argv) { (milliseconds: Int?) in
                    Interpreter.timeout = milliseconds
                }
            }

            module.def("enable_trace() -> None",
                       docstring: "Enables Python line tracing for the current interpreter.") { argc, argv in
                PyBind.function(argc, argv) {
                    Interpreter.enableTrace()
                }
            }

            module.def("disable_trace() -> None",
                       docstring: "Disables Python line tracing for the current interpreter.") { argc, argv in
                PyBind.function(argc, argv) {
                    Interpreter.disableTrace()
                }
            }

            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            module.app_version = appVersion
            module.pocketpy_version = py.version
        }

        bindModule("interpreter", in: .module)
    }
}
