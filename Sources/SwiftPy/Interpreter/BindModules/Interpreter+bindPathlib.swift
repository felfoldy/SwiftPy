//
//  Interpreter+bindPathlib.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-10.
//

extension Interpreter {
    func bindPathlib() {
        bindModule("pathlib", docs: "Object-oriented filesystem paths.") { module in
            module.class(Path.self)
        }
    }
}
