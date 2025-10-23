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
        py_callbacks().pointee.print = { cString in
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
        
        py_callbacks().pointee.lazyimport = { cName in
            guard let cName else { return nil }
            let name = String(cString: cName)
            
            if let lib = Interpreter.moduleBuilders[name] {
                let module = py_newmodule(name)
                lib(module)
                return module
            }
            
            return nil
        }

        py_callbacks().pointee.importfile = { cFilename in
            guard let cFilename else { return nil }
            
            let filename = String(cString: cFilename)
            if let content = Interpreter.importFromBundle(name: filename) {
                return strdup(content)
            }

            return nil
        }
        
        py_callbacks().pointee.displayhook = { obj in
            guard let obj else { return }
            
            if let view = obj.view {
                Interpreter.output.view(view)
                return
            }

            do {
                try Interpreter.printErrors {
                    py_repr(obj)
                }
                
                if let str = String(PyAPI.returnValue) {
                    Interpreter.output.stdout(str)
                }
            } catch {}
        }
    }
}
