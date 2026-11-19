import Foundation
import Markdown

/// A common interface for Markdown lint rules that operate on a parsed document.
/// Each rule inspects the entire document and reports violations as ``Diagnostic`` values.
///
/// A rule that can fix a violation attaches a ``FixIt`` to its diagnostic. The fix-it and the
/// diagnostic come from the same scan, so what is reported is what gets fixed.
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
  ///     file. The ranges of fix-its refer to this text and must leave the placeholder
  ///     characters alone.
  /// - Returns: An array of ``Diagnostic`` values describing the violations.
  func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic]
}
