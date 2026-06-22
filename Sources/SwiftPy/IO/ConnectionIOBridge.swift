//
//  ConnectionIOBridge.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 06. 18..
//

extension Interpreter {
    func connectionIOBridge() async {
        for await event in await connection.events {
            switch event.payload {
            case let .stdout(text):
                Interpreter.output.stdout(text)
            case let .stderr(text):
                Interpreter.output.stderr(text)
            default:
                break
            }
        }
    }
}
