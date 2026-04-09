//
//  Interpreter+setCallbacks.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-04.
//

import Foundation
import pocketpy

extension Interpreter {
    /// Sets print output, importhook, importfile.
    func setCallbacks() {
        py.callbacks.print = { cString in
            guard let cString else { return }
            let str = String(cString: cString)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if str.isEmpty { return }
            
            if Interpreter.isFailed {
                Interpreter.output.stderr(str)
                Interpreter.isFailed = false
                Interpreter.lastFailure = str
            } else {
                Interpreter.output.stdout(str)
            }
        }

        py.callbacks.lazyimport = { cName in
            guard let cName else { return nil }
            let name = String(cString: cName)
            
            if let lib = Interpreter.moduleBuilders[name] {
                let module = py.newmodule(name)
                lib(module)
                return module
            }
            
            return nil
        }

        py.callbacks.importfile = { cFilename, _ in
            guard let cFilename else { return nil }
            
            let filename = String(cString: cFilename)
            if let content = Interpreter.importFromSource(name: filename) {
                return strdup(content)
            }

            return nil
        }
        
        py.callbacks.displayhook = { obj in
            if py.istype(obj, type: .None) { return true }
            
            if let view = obj?.view {
                Interpreter.output.view(view)
                return true
            }

            do {
                try Interpreter.printErrors {
                    py.repr(obj)
                }
                
                if let str = String(py.retval) {
                    Interpreter.output.stdout(str)
                }
            } catch {}
            return true
        }
    }
}
