//
//  AsyncParser.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-27.
//

import Foundation

/// How a parsed chunk of Python relates to `await`.
enum AsyncCall: Equatable {
    /// No awaited call — run the whole chunk and resume immediately.
    case plain

    /// An awaited call, optionally binding its result to `resultName`.
    case awaiting(resultName: String?)

    /// Whether an awaited call was found.
    var isAwaiting: Bool {
        if case .awaiting = self { return true }
        return false
    }
}

/// Splits a chunk of Python source into the leading `await` call and the
/// deferred continuation.
struct AsyncParser {
    /// The code to run now: the awaited call when matched, otherwise the whole
    /// source.
    let code: String

    /// The remaining source after the matched line, to run once `code`
    /// completes.
    let continuationCode: String?

    /// Classifies whether `code` is an awaited call and what it binds.
    let call: AsyncCall

    init(_ source: String) {
        let lines = source.components(separatedBy: .newlines)

        var codeToExecute = [String]()

        let pattern = #"^(?:(?<resultName>\w+)\s*=\s*)?await\s+(?<call>[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\([^)]*\))$"#

        // Precompile the regex.
        let regex = try! NSRegularExpression(pattern: pattern, options: [])

        for i in 0..<lines.count {
            let line = lines[i]
            let range = NSRange(location: 0, length: line.utf16.count)

            if let result = regex.firstMatch(in: line, options: [], range: range) {
                guard let callRange = Range(result.range(withName: "call"), in: line) else {
                    continue
                }
                let matchedCall = String(line[callRange])

                // Capture the result name if it exists.
                var capturedResultName: String? = nil
                let resultNameRange = result.range(withName: "resultName")
                if resultNameRange.location != NSNotFound,
                   let rnRange = Range(resultNameRange, in: line) {
                    capturedResultName = String(line[rnRange])
                }

                // Run only the awaited call; defer the rest as continuation.
                codeToExecute.append(matchedCall)
                code = codeToExecute.joined(separator: "\n")
                continuationCode = Self.joinRest(lines, from: i + 1)
                call = .awaiting(resultName: capturedResultName)
                return
            }

            codeToExecute.append(line)
        }

        code = source
        continuationCode = nil
        call = .plain
    }

    private static func joinRest(_ lines: [String], from i: Int) -> String? {
        if i >= lines.count {
            return nil
        }

        return lines[i..<lines.count]
            .joined(separator: "\n")
    }
}
