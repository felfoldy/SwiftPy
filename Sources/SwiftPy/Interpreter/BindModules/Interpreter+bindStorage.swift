//
//  Interpreter+bindStorage.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-11.
//

extension Interpreter {
    func bindStorage() {
        bindModule("storage.native") { module in
            if #available(macOS 15, iOS 18, visionOS 2, *) {
                module.classes(
                    Store.self,
                    ModelHandle.self,
                    StoreObservation.self,
                )
            }
        }

        bindModule("storage", in: .module)
    }
}
