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

            module.def("app_name() -> str",
                       docstring: "Return the name of the app the interpreter runs in.") { argc, argv in
                PyBind.function(argc, argv) {
                    let info = Bundle.main.infoDictionary
                    return info?["CFBundleDisplayName"] as? String
                        ?? info?["CFBundleName"] as? String
                        ?? ProcessInfo.processInfo.processName
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
                    Interpreter.display(view)
                }
            }

            module.asyncDef(
                "ainput(prompt: str = '', images: bool = False, multiline: bool = False) -> InputResult",
                docstring: """
                Asks the user for an answer, as `input` does, but to await: \
                the rest of the program, such as a button's action, keeps \
                running while it waits.

                prompt: What to ask.
                images: Whether the user can attach images, which the answer's `images` holds.
                multiline: Whether the answer can run to several lines. Otherwise it's one, which Return sends.

                Returns an ``interpreter.InputResult``: the text, as a str, with the images attached.

                ```python
                from interpreter import ainput

                name = await ainput("What's your name?")

                answer = await ainput("What should change?", images=True)
                await agent.respond(answer, images=answer.images)
                ```
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { (prompt: String, images: Bool, multiline: Bool) in
                    try await Interpreter.answer(InputRequest(prompt: prompt, acceptsImages: images, isMultiline: multiline))
                }
            }

            // The builtin `input`: what `ainput` asks, waited for as Python's is.
            module.def(
                "input(prompt: str = '', images: bool = False, multiline: bool = False) -> InputResult",
                docstring: """
                Asks the user for an answer, and waits for it.

                prompt: What to ask.
                images: Whether the user can attach images, which the answer's `images` holds.
                multiline: Whether the answer can run to several lines. Otherwise it's one, which Return sends.

                Returns an ``interpreter.InputResult``: the text, as a str, with the images attached.
                """
            ) { argc, argv in
                PyBind.blocking(argc, argv) { (prompt: String, images: Bool, multiline: Bool) in
                    try await Interpreter.answer(InputRequest(prompt: prompt, acceptsImages: images, isMultiline: multiline))
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

            // What a console cell echoes an expression's value through: a
            // view is presented, anything else prints as its repr.
            module.def("_displayhook(value) -> None") { argc, argv in
                PyBind.function(argc, argv) { (value: PyObject?) -> Void in
                    guard let value else { return }
                    Interpreter.shared.connection.display(viewObject: value.reference)
                }
            }

            py.module("builtins")?.input = module.input

            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            module.app_version = appVersion
            module.pocketpy_version = py.version

            #if cpython
            // pocketpy reaches the hook through a callback; CPython through sys.
            if let hook: PyObject = module._displayhook {
                py.module("sys")?.displayhook = hook
            }
            py.module("builtins")?.View = PyType.View.object
            ViewState.installSetattr()
            #endif
        }

        bindModule("interpreter", in: .module)
    }
}

extension Interpreter {
    /// The host's answer, as `interpreter.InputResult`.
    @MainActor
    static func answer(_ request: InputRequest) async throws -> PyObject {
        let response = try await requestInput(request)
        guard let make = py.module("interpreter")?._input_result else {
            throw PythonError.RuntimeError("interpreter.InputResult is missing")
        }
        return try make(response.text, response.images)
    }
}
