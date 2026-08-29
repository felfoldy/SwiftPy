//
//  Interpreter+bindString.swift
//  SwiftPy
//

import Foundation

extension Interpreter {
    func bindString() {
        PyType.str.function(
            "title(self) -> str",
            "Return a titlecased version of the string, with each word starting with an uppercase character."
        ) { argc, argv in
            PyBind.function(argc, argv) { (value: String) in
                value.pythonTitlecased
            }
        }

        PyType.str.function(
            "rsplit(self, sep=None, maxsplit=-1) -> list[str]",
            "Return a list of the words in the string, using sep as the delimiter string, starting at the end of the string."
        ) { argc, argv in
            PyBind.function(argc, argv) { (value: String, separator: String?, maxsplit: Int) in
                try value.pythonRSplit(separator: separator, maxsplit: maxsplit)
            }
        }
    }
}

private extension String {
    var pythonTitlecased: String {
        var previousCharacterIsCased = false

        return map { character in
            let value = String(character)
            let isCased = value.lowercased() != value.uppercased()
            defer { previousCharacterIsCased = isCased }

            guard isCased else { return value }
            return previousCharacterIsCased
                ? value.lowercased()
                : value.capitalized(with: Locale(identifier: "en_US_POSIX"))
        }.joined()
    }

    func pythonRSplit(separator: String?, maxsplit: Int) throws -> [String] {
        if let separator {
            guard !separator.isEmpty else {
                throw PythonError.ValueError("empty separator")
            }
            return splitFromRight(separator: separator, maxsplit: maxsplit)
        }
        return splitWhitespaceFromRight(maxsplit: maxsplit)
    }

    func splitFromRight(separator: String, maxsplit: Int) -> [String] {
        guard maxsplit != 0 else { return [self] }
        var parts = [String]()
        var remaining = self[...]
        while maxsplit < 0 || parts.count < maxsplit {
            guard let range = remaining.range(of: separator, options: .backwards) else { break }
            parts.append(String(remaining[range.upperBound...]))
            remaining = remaining[..<range.lowerBound]
        }
        parts.append(String(remaining))
        return parts.reversed()
    }

    func splitWhitespaceFromRight(maxsplit: Int) -> [String] {
        var end = endIndex
        while end > startIndex, self[index(before: end)].isWhitespace {
            end = index(before: end)
        }
        guard end > startIndex else { return [] }
        guard maxsplit != 0 else { return [String(self[..<end])] }

        var parts = [String]()
        var cursor = end
        while cursor > startIndex, maxsplit < 0 || parts.count < maxsplit {
            var wordStart = cursor
            while wordStart > startIndex, !self[index(before: wordStart)].isWhitespace {
                wordStart = index(before: wordStart)
            }
            parts.append(String(self[wordStart..<cursor]))
            cursor = wordStart
            while cursor > startIndex, self[index(before: cursor)].isWhitespace {
                cursor = index(before: cursor)
            }
        }
        if cursor > startIndex {
            parts.append(String(self[..<cursor]))
        }
        return parts.reversed()
    }
}
