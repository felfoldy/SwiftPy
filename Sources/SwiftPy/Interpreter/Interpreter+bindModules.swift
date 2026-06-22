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

extension Interpreter {
    func bindBuiltins() {
        let builtins = py.getmodule("builtins")

        // Add async decorator.
        let asyncSource = """
        def async(func):
            import asyncio
            def coroutine(*args,**kwargs):
                cr = func(*args,**kwargs)
                return asyncio.AsyncTask(cr)
            return coroutine
        """

        _ = try? py.exec(
            source: asyncSource,
            filename: "<stdin>",
            mode: .execution,
            module: builtins
        )

        // Add View type.
        py.setdict(builtins, name: "View", value:  py.tpobject(.View))
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
        bindModule("asyncio") { module in
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
        guard let sys = py.getmodule("sys") else { return }

        #if os(visionOS)
        let osName = "visionos"
        #elseif os(iOS)
        let osName = UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios"
        #elseif os(macOS)
        let osName = "macos"
        #else
        let osName = "unknown"
        #endif

        let osNameRef = py.retain(osName)
        _ = try? py.setattr(
            sys,
            name: "os",
            value: osNameRef?.reference
        )
    }
    
    func bindInterpreter() {
        bindModule("interpreter.native") { module in
            module.def("host(name: str) -> None",
                       docstring: "Hosts the remote Python interpreter on this device.") { argc, argv in
                PyBind.function(argc, argv) { (name: String) in
                    // TODO: Refactor hosting.
                    return
                }
            }
        }
    }
    
    func bindPathlib() {
        bindModule("pathlib") { module in
            module.class(Path.self)
        }
    }
    
    func bindP2P() {
        bindModule("p2p") { module in
            module.class(Peer.self)
        }
    }
    
    func bindStorages() {
        bindModule("storages") { module in
            if #available(macOS 15, iOS 18, visionOS 2, *) {
                module.classes(
                    ModelContainer.self,
                    ModelData.self,
                    LookupKeyValue.self,
                )
            }
        }
    }
}
