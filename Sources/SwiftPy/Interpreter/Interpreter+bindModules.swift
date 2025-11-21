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
        
        Interpreter.bindModule("interpreter", [
            ViewRepresentation.self,
        ])

        Interpreter.bindModule("asyncio", [
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

        Interpreter.bindModule("pathlib", [
            Path.self,
        ])
    }
    
    private static func bindOS() {
        let os = py_getmodule("os")

        os?.bind(
            "chdir(path: str) -> None",
            docstring: "Change the current working directory to the specified path."
        ) { _, path in
            PyAPI.returnOrThrow {
                if let path = String(path) {
                    FileManager.default.changeCurrentDirectoryPath(path)
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
