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
  /// Code blocks, inline code, and raw HTML are hidden from the rules by a
  /// ``MaskedSource``, so they are neither reported nor rewritten.
  ///
  /// - Parameters:
  ///   - content: The Markdown source to lint.
  ///   - fileURL: The URL used in diagnostics to identify the document.
  ///   - applyFixes: A Boolean value that indicates whether auto-fixable rules
  ///     should mutate the Markdown text.
  /// - Returns: A tuple that contains the diagnostics collected from the
  ///   original `content` and, when `applyFixes` is `true`, the fixed Markdown
  ///   string. The second element is `nil` when `applyFixes` is `false`.
  public func lint(content: String, fileURL: URL, applyFixes: Bool) -> ([Diagnostic], String?) {
    let document = Document(parsing: content)
    let source = MaskedSource(content: content, document: document)
    var diagnostics: [Diagnostic] = []

    for rule in rules {
      diagnostics.append(
        contentsOf: rule.check(document: document, fileURL: fileURL, originalText: source.text))
    }

    guard applyFixes else { return (diagnostics, nil) }

    var maskedText = source.text
    var fixed = content
    for rule in rules {
      guard let fixableRule = rule as? AutoFixable else { continue }
      let candidate = fixableRule.fixing(originalText: maskedText)
      // A fix that disturbed the placeholders cannot be mapped back onto the
      // hidden regions, so it is dropped rather than risk corrupting them.
      guard let restored = source.unmasking(candidate) else { continue }
      maskedText = candidate
      fixed = restored
    }
    return (diagnostics, fixed)
  }
}
