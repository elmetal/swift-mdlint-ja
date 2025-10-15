import Foundation
import Markdown

/// A common interface for Markdown lint rules that operate on a parsed document.
/// Each rule inspects the entire document and reports violations as ``Diagnostic`` values.
public protocol Rule {
    /// A unique identifier string for the rule.
    var id: String { get }
    /// A human-readable description that summarizes the purpose of the rule.
    var description: String { get }
    /// Inspects the Markdown document and returns any detected violations.
    /// - Parameters:
    ///   - document: The parsed Markdown abstract syntax tree to check.
    ///   - fileURL: The URL of the file currently being linted.
    ///   - originalText: The original Markdown source text.
    /// - Returns: An array of ``Diagnostic`` values describing the violations.
    func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic]
}

/// A protocol that marks a rule as capable of providing automatic fixes for its violations.
public protocol AutoFixable {
    /// Returns a new Markdown text with the violations fixed.
    func fixing(originalText: String) -> String
}
