import Foundation
import Markdown

public protocol Rule {
    var id: String { get }
    var description: String { get }
    /// Whether this rule can auto-fix the violation.
    var isFixable: Bool { get }
    func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic]
    func fix(originalText: String) -> String
}

public enum DefaultRules {
    public static let all: [Rule] = [
        JapanesePeriodRule(),
        HeadingTerminalPunctuationRule(),
        HeadingLevelSkipRule()
    ]
}