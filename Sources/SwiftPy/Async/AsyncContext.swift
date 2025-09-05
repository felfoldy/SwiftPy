//
//  AsyncContext.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import pocketpy
import Foundation

@MainActor
struct AsyncContext {
    static var current: AsyncContext?
    
    let code: String
    let continuationCode: String?
    let resultName: String?
    let didMatch: Bool

    let completion: () -> Void
    let filename: String
    let mode: CompileMode

    init(_ code: String, filename: String, mode: CompileMode, completion: @escaping () -> Void) {
        self.filename = filename
        self.completion = completion
        self.mode = mode
        
        let lines = code.components(separatedBy: .newlines)
        
        var codeToExecute = [String]()

        let pattern = #"^(?:(?<resultName>\w+)\s*=\s*)?await\s+(?<call>[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\([^)]*\))$"#
        
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
                codeToExecute.append(call)
                self.code = codeToExecute.joined(separator: "\n")
                self.continuationCode = Self.joinRest(lines, from: i + 1)
                self.resultName = capturedResultName
                didMatch = true
                return
            }
            
            codeToExecute.append(line)
        }
        
        self.code = code
        continuationCode = nil
        resultName = nil
        didMatch = false
    }
    
    static func joinRest(_ lines: [String], from i: Int) -> String? {
        if i >= lines.count {
            return nil
        }
        
        return lines[i..<lines.count]
            .joined(separator: "\n")
    }
}
