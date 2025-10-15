import Foundation
import Markdown

/// Runs a collection of lint rules against Markdown documents.
///
/// ``Linter`` coordinates the execution of multiple ``Rule`` instances and
/// aggregates their diagnostics. It can optionally apply automatic fixes from
/// rules that conform to ``AutoFixable`` and return the corrected Markdown
/// source alongside the diagnostics.
public struct Linter {
    private let rules: [Rule]

    /// Creates a linter that executes the specified rules in order.
    ///
    /// - Parameter rules: The collection of rules to evaluate for each
    ///   document. The order of the array determines the order in which
    ///   diagnostics are produced and fixes are applied.
    public init(rules: [Rule]) {
        self.rules = rules
    }

    /// Lints the given Markdown text and optionally applies automatic fixes.
    ///
    /// - Parameters:
    ///   - content: The Markdown source to lint.
    ///   - fileURL: The URL used in diagnostics to identify the document.
    ///   - applyFixes: A Boolean value that indicates whether auto-fixable rules
    ///     should mutate the Markdown text.
    /// - Returns: A tuple that contains the collected diagnostics and, when
    ///   ``applyFixes`` is `true`, the fixed Markdown string. The second element
    ///   is `nil` when no fixes are applied.
    public func lint(content: String, fileURL: URL, applyFixes: Bool) -> ([Diagnostic], String?) {
        let document = Document(parsing: content)
        var diagnostics: [Diagnostic] = []

        for rule in rules {
            diagnostics.append(contentsOf: rule.check(document: document, fileURL: fileURL, originalText: content))
        }

        if applyFixes {
            var fixed = content
            for rule in rules {
                if let fixableRule = rule as? AutoFixable {
                    fixed = fixableRule.fixing(originalText: fixed)
                }
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