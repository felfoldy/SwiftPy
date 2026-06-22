//
//  Interpreter+setCallbacks.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-04.
//

import Foundation

extension Interpreter {
    /// Sets print output, importhook, importfile.
    func setCallbacks() {
        // TODO: Check if Apple accepts redirection.
        // py.callbacks.print = { str in
        //     guard let str else { return }
        //     let content = String(cString: str)
        //     Task {
        //         await Interpreter.shared.connection
        //             .send(id: 0, .stdout(text: content))
        //     }
        // }
        
        py.callbacks.lazyimport = { cName in
            guard let cName else { return nil }
            let name = String(cString: cName)
            
            if let lib = Interpreter.shared.moduleFactory[name] {
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
                try print(py.repr(obj))
            } catch {}
            return true
        }
    }
}
