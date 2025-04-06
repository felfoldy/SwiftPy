//
//  AsyncDecoder.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import pocketpy
import Foundation

struct AsyncDecoder {
    let code: String
    let continuationCode: String?
    let resultName: String?
    
    init(_ code: String) {
        let lines = code.components(separatedBy: .newlines)
        
        var codeToExecute = [String]()
        
        // Regex pattern:
        // ^ -> start of line (no leading whitespace)
        // (?:(?<resultName>\w+)\s*=\s*)? -> optional assignment capturing the result name
        // await\s+ -> literal "await" followed by at least one space
        // (?<call>\w+\([^)]*\)) -> capture the function call (function name + arguments)
        // $ -> end of line
        let pattern = #"^(?:(?<resultName>\w+)\s*=\s*)?await\s+(?<call>\w+\([^)]*\))$"#
        
        // Precompile the regex.
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        
        for i in 0..<lines.count {
            let line = lines[i]
            let range = NSRange(location: 0, length: line.utf16.count)
            
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                guard let callRange = Range(match.range(withName: "call"), in: line) else {
                    continue
                }
                let call = String(line[callRange])
                
                // Capture the result name if it exists.
                var capturedResultName: String? = nil
                let resultNameRange = match.range(withName: "resultName")
                if resultNameRange.location != NSNotFound,
                   let rnRange = Range(resultNameRange, in: line) {
                    capturedResultName = String(line[rnRange])
                }
                
                // Replace the matched line with "task = <call>"
                let newLine = "task = \(call)"
                codeToExecute.append(newLine)
                self.code = codeToExecute.joined(separator: "\n")
                self.continuationCode = Self.joinRest(lines, from: i + 1)
                self.resultName = capturedResultName
                return
            }
            
            codeToExecute.append(line)
        }
        
        self.code = code
        continuationCode = nil
        resultName = nil
    }
    
    static func joinRest(_ lines: [String], from i: Int) -> String? {
        if i >= lines.count {
            return nil
        }
        
        return lines[i..<lines.count]
            .joined(separator: "\n")
    }
}
