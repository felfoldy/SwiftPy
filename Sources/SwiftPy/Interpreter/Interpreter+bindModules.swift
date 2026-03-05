//
//  Interpreter+bindModules.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-11-19.
//

import pocketpy
import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension Interpreter {
    static func bindModules() {
        bindOS()
        bindSys()
        
        PyBind.module("interpreter", [
            ViewRepresentation.self,
        ]) { module in
            let builtins = py_getmodule("builtins")
            builtins?["dir"]?.assign(module?["dir"])
            
            module?.bind(
                "host(name: str) -> None",
                docstring: "Hosts the remote Python interpreter on this device."
            ) { _, argv in
                PyAPI.returnOrThrow {
                    let name = try String.cast(argv)
                    let remote = RemoteIOStream(name: name)
                    Interpreter.output = MultiIOStream(streams: [Interpreter.output, remote])
                    return .none
                }
            }
        }

        PyBind.module("asyncio", [
            AsyncTask.self,
        ]) { module in
            module?.bind(
                "sleep(seconds: float) -> None",
                docstring: "Coroutine that completes after a given time (in seconds)."
            ) { argc, argv in
                PyBind.function(argc, argv) { (seconds: Double) in
                    let sleep = AsyncSleep(seconds: seconds)
                    return sleep.task
                }
            }
        }

        PyBind.module("pathlib", [
            Path.self,
        ])

        PyBind.module("p2p", [
            Peer.self,
        ])
    }
    
    private static func bindOS() {
        let os = py_getmodule("os")

        os?.bind(
            "chdir(path: str | Path) -> None",
            docstring: "Change the current working directory to the specified path."
        ) { _, path in
            PyAPI.returnOrThrow {
                if let path = String(path) {
                    FileManager.default.changeCurrentDirectoryPath(path)
                    return
                }

                if let path = Path(path) {
                    FileManager.default.changeCurrentDirectoryPath(path.url.path)
                    return
                }

                throw PythonError.AssertionError("Path must be a string.")
            }
        }

        os?.bind(
            "getcwd() -> str",
            docstring: "Return a unicode string representing the current working directory."
        ) { _, _ in
            PyAPI.return(FileManager.default.currentDirectoryPath)
        }
    }
    
    private static func bindSys() {
        let sys = py_getmodule("sys")

        #if os(visionOS)
        let osName = "visionos"
        #elseif os(iOS)
        let osName = UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios"
        #elseif os(macOS)
        let osName = "macos"
        #else
        let osName = "unknown"
        #endif
        
        let osNameRef = osName.toStack
        py_setattr(sys, py_name("os"), osNameRef.reference)
    }
}
