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
  /// HTML comments in the document turn rules off for part of it:
  /// `<!-- mdlint-disable -->` and `<!-- mdlint-enable -->` delimit a range of
  /// lines, and `<!-- mdlint-disable-next-line -->` covers the line after the
  /// comment. Each applies to every rule, or to the rule identifiers listed
  /// after the keyword. On the lines where a rule is off, its diagnostics are
  /// not returned and its fixes are not applied.
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
    let directives = DisableDirectives(document: document)
    var diagnostics: [Diagnostic] = []

    for rule in rules {
      let found = rule.check(document: document, fileURL: fileURL, originalText: source.text)
      diagnostics.append(
        contentsOf: found.filter { !directives.disables($0.ruleID, atLine: $0.line) })
    }

    guard applyFixes else { return (diagnostics, nil) }

    var maskedText = source.text
    var fixed = content
    for rule in rules {
      guard let fixableRule = rule as? AutoFixable else { continue }
      var candidate = fixableRule.fixing(originalText: maskedText)
      if !directives.isEmpty {
        // The directives refer to lines, so a fix that changes the number of
        // lines is dropped: neither this rule nor the ones after it could
        // tell any more which lines are turned off.
        guard
          let kept = directives.keepingDisabledLines(
            of: maskedText, in: candidate, for: rule.id)
        else { continue }
        candidate = kept
      }
      // A fix that disturbed the placeholders cannot be mapped back onto the
      // hidden regions, so it is dropped rather than risk corrupting them.
      guard let restored = source.unmasking(candidate) else { continue }
      maskedText = candidate
      fixed = restored
    }
    return (diagnostics, fixed)
  }
}
