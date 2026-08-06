//
//  Interpreter+bindModules.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-11-19.
//

import Foundation
#if canImport(UIKit)
import UIKit
import SwiftUI
#endif

import pocketpy

extension Interpreter {
    func bindBuiltins() {
        let builtins = py.module("builtins")

        // Add async decorator.
        let asyncSource = """
        def async(func):
            import functools
            import asyncio
            import inspect
            if not inspect.isgeneratorfunction(func):
                return func
            @functools.wraps(func)
            def coroutine(*args,**kwargs):
                return asyncio.AsyncTask(func(*args,**kwargs))
            return coroutine
        """

        _ = try? py.exec(
            source: asyncSource,
            filename: "<string>",
            mode: .execution,
            module: builtins?.reference
        )

        builtins?.View = py.tpobject(.View)
    }

    func bindOS() {
        let os = py.getmodule("os")

        os?.bind(
            "chdir(path: str | Path) -> None",
            docstring: "Change the current working directory to the specified path."
        ) { _, path in
            PyAPI.return {
                if let path = String(path) {
                    FileManager.default.changeCurrentDirectoryPath(path)
                    return .none
                }

                throw PythonError.AssertionError("Path must be a string.")
            }
        }

        os?.bind(
            "getcwd() -> str",
            docstring: "Return a unicode string representing the current working directory."
        ) { _, _ in
            PyAPI.return { FileManager.default.currentDirectoryPath }
        }
    }

    func bindAsyncio() {
        bindModule("asyncio", docs: "Async task utilities.") { module in
            module.class(AsyncTask.self)

            module.def(
                "sleep(seconds: float) -> None",
                docstring: "Coroutine that completes after a given time (in seconds)."
            ) { argc, argv in
                PyBind.function(argc, argv) { (seconds: Double) in
                    AsyncSleep(seconds: seconds).task
                }
            }
        }
    }
    
    func bindSys() {
        #if os(visionOS)
        let osName = "visionos"
        #elseif os(iOS)
        let osName = UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios"
        #elseif os(macOS)
        let osName = "macos"
        #else
        let osName = "unknown"
        #endif

        let sys = py.module("sys")
        sys?.os = osName
    }
    
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

            module.def("display(view) -> None",
                       docstring: "Presents a view in the console.") { argc, argv in
                PyBind.function(argc, argv) { (view: PyObject) -> Void in
                    guard let view = view.reference.view else { return }
                    Interpreter.onDisplay(view)
                }
            }

            module.def("set_timeout(milliseconds: int | None) -> None",
                       docstring: "Sets the execution timeout in milliseconds, or None to disable it.") { argc, argv in
                PyBind.function(argc, argv) { (milliseconds: Int?) in
                    Interpreter.timeout = milliseconds
                }
            }

            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            module.app_version = appVersion
            module.pocketpy_version = py.version
        }

        bindModule("interpreter", in: .module)
    }
    
    func bindPathlib() {
        bindModule("pathlib", docs: "Object-oriented filesystem paths.") { module in
            module.class(Path.self)
        }
    }
    
    func bindP2P() {
        bindModule("p2p", docs: "Peer-to-peer discovery and messaging.") { module in
            module.class(Peer.self)
        }
    }

    func bindStorage() {
        bindModule("storage.native") { module in
            if #available(macOS 15, iOS 18, visionOS 2, *) {
                module.classes(
                    Store.self,
                    ModelData.self,
                    LookupKeyValue.self,
                )
            }
        }

        bindModule("modeling", in: .module)
        bindModule("storage", in: .module)
    }
}
