//
//  AsyncDecoder.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import pocketpy

struct AsyncDecoder {
    let code: String
    let continuationCode: String?
    
    init(_ code: String) {
        let lines = code.components(separatedBy: .newlines)
        
        var codeToExecute = [String]()
                
        for i in 0..<lines.count  {
            let line = lines[i]

            if line.starts(with: "await ") {
                let newLine = line.replacingOccurrences(of: "await ", with: "task = ")
                codeToExecute.append(newLine)
                
                self.code = codeToExecute.joined(separator: "\n")
                continuationCode = Self.joinRest(lines, from: i + 1)
                
                return
            }

            codeToExecute.append(line)
        }

        self.code = code
        self.continuationCode = nil
    }
    
    static func joinRest(_ lines: [String], from i: Int) -> String? {
        if i >= lines.count {
            return nil
        }
        
        return lines[i..<lines.count]
            .joined(separator: "\n")
    }
}
