import Foundation
import Markdown

public final class Linter {
    private let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }

    public func lint(content: String, fileURL: URL, applyFixes: Bool) -> ([Diagnostic], String?) {
        let document = Document(parsing: content)
        var diagnostics: [Diagnostic] = []

        for rule in rules {
            diagnostics.append(contentsOf: rule.check(document: document, fileURL: fileURL, originalText: content))
        }

        if applyFixes {
            var fixed = content
            for rule in rules where rule.isFixable {
                fixed = rule.fix(originalText: fixed)
            }
            return (diagnostics, fixed)
        } else {
            return (diagnostics, nil)
        }
    }
}

// MARK: - Helpers

extension String {
    /// Returns (line, column) for the given UTF16-based index (simple heuristic).
    func lineColumn(for utf16Offset: Int) -> (line: Int, column: Int) {
        var line = 1
        var column = 1
        var count = 0
        for ch in self {
            if count >= utf16Offset { break }
            if ch == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            count += String(ch).utf16.count
        }
        return (line, column)
    }
}