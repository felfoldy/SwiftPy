// The module bindings are pocketpy's; a CPython run boots without them.
#if !cpython
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

        bindString()

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
            coroutine._is_async = True
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
#endif
