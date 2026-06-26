//
//  AsyncContext.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import Foundation

@MainActor
struct AsyncContext: @unchecked Sendable {
    @TaskLocal static var current: AsyncContext?
    
    let code: String
    let continuationCode: String?
    let resultName: String?
    let didMatch: Bool

    /// The matched ``code`` compiled into a Python code object, ready to run.
    let compiledCode: PyObject

    // Bound at execution time by `asyncExecute(_:)`; a compiled context carries
    // a no-op until then so it can be reused across executions.
    var completion: () -> Void = {}
    let filename: String
    let mode: CompileMode

    init(_ code: String, filename: String, mode: CompileMode) throws(PythonError) {
        self.filename = filename
        self.mode = mode

        let lines = code.components(separatedBy: .newlines)

        var codeToExecute = [String]()

        let pattern = #"^(?:(?<resultName>\w+)\s*=\s*)?await\s+(?<call>[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\([^)]*\))$"#

        // Precompile the regex.
        let regex = try! NSRegularExpression(pattern: pattern, options: [])

        var match: (code: String, continuationCode: String?, resultName: String?)?

        for i in 0..<lines.count {
            let line = lines[i]
            let range = NSRange(location: 0, length: line.utf16.count)

            if let result = regex.firstMatch(in: line, options: [], range: range) {
                guard let callRange = Range(result.range(withName: "call"), in: line) else {
                    continue
                }
                let call = String(line[callRange])

                // Capture the result name if it exists.
                var capturedResultName: String? = nil
                let resultNameRange = result.range(withName: "resultName")
                if resultNameRange.location != NSNotFound,
                   let rnRange = Range(resultNameRange, in: line) {
                    capturedResultName = String(line[rnRange])
                }

                // Run only the awaited call; defer the rest as continuation.
                codeToExecute.append(call)
                match = (codeToExecute.joined(separator: "\n"),
                         Self.joinRest(lines, from: i + 1),
                         capturedResultName)
                break
            }

            codeToExecute.append(line)
        }

        if let match {
            self.code = match.code
            self.continuationCode = match.continuationCode
            self.resultName = match.resultName
            didMatch = true
        } else {
            self.code = code
            continuationCode = nil
            resultName = nil
            didMatch = false
        }

        compiledCode = PyObject(try py.compile(source: self.code, filename: filename, mode: mode))
    }
    
    static func joinRest(_ lines: [String], from i: Int) -> String? {
        if i >= lines.count {
            return nil
        }
        
        return lines[i..<lines.count]
            .joined(separator: "\n")
    }
    
    func complete(result: PyObject?) async {
        if let resultName {
            py.main[dynamicMember: resultName] = result
        }

        if let continuationCode {
            await Interpreter.shared.asyncExecute(
                continuationCode,
                filename: filename, mode: mode
            )
        }

        completion()
    }
}
