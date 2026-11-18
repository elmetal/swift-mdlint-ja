import Foundation
import Markdown

/// A common interface for Markdown lint rules that operate on a parsed document.
/// Each rule inspects the entire document and reports violations as ``Diagnostic`` values.
public protocol Rule: Sendable {
  /// A unique identifier string for the rule.
  var id: String { get }
  /// A human-readable description that summarizes the purpose of the rule.
  var description: String { get }
  /// Inspects the Markdown document and returns any detected violations.
  /// - Parameters:
  ///   - document: The parsed Markdown abstract syntax tree to check.
  ///   - fileURL: The URL of the file currently being linted.
  ///   - originalText: The Markdown source text with code blocks, inline code, and raw HTML
  ///     replaced by placeholders (see ``MaskedSource``). Lines and columns match the original
  ///     file.
  /// - Returns: An array of ``Diagnostic`` values describing the violations.
  func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic]
}

/// A protocol that marks a rule as capable of providing automatic fixes for its violations.
public protocol AutoFixable {
  /// Returns a new Markdown text with the violations fixed.
  ///
  /// The text is masked in the same way as in ``Rule/check(document:fileURL:originalText:)``.
  /// A fix must leave the placeholder characters where they are; the linter discards a fix that
  /// adds, removes, or reorders them.
  func fixing(originalText: String) -> String
}
