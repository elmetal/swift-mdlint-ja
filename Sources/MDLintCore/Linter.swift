import Foundation
import Markdown

/// Runs a collection of lint rules against Markdown documents.
///
/// ``Linter`` coordinates the execution of multiple ``Rule`` instances and
/// aggregates their diagnostics. It can optionally apply the ``FixIt`` values
/// that the diagnostics carry and return the corrected Markdown source
/// alongside the diagnostics.
public struct Linter {
  private let rules: [Rule]

  /// The number of times the linter checks a document again after applying
  /// fix-its, at most.
  private static let maximumFixPasses = 10

  /// Creates a linter that executes the specified rules in order.
  ///
  /// - Parameter rules: The collection of rules to evaluate for each
  ///   document. The order of the array determines the order in which
  ///   diagnostics are produced, and which of two overlapping fix-its is
  ///   applied first.
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
  /// not returned and their fix-its are not applied.
  ///
  /// With `applyFixes`, the linter applies the fix-its of the diagnostics it
  /// found, checks the result again, and repeats until nothing is left to
  /// fix, because one fix can uncover or create another violation. Of two
  /// fix-its that overlap, the one that starts earlier is applied, or the one
  /// of the earlier rule when they start together; the other gets its turn in
  /// the next pass if its violation is still there.
  ///
  /// - Parameters:
  ///   - content: The Markdown source to lint.
  ///   - fileURL: The URL used in diagnostics to identify the document.
  ///   - applyFixes: A Boolean value that indicates whether fix-its should be
  ///     applied to the Markdown text.
  /// - Returns: A tuple that contains the diagnostics collected from the
  ///   original `content` and, when `applyFixes` is `true`, the fixed Markdown
  ///   string. The second element is `nil` when `applyFixes` is `false`.
  public func lint(content: String, fileURL: URL, applyFixes: Bool) -> ([Diagnostic], String?) {
    let (diagnostics, source) = check(content, fileURL: fileURL)
    guard applyFixes else { return (diagnostics, nil) }

    var fixed = content
    var pass = (diagnostics: diagnostics, source: source)
    for _ in 1...Self.maximumFixPasses {
      guard
        let edited = Self.applying(pass.diagnostics.compactMap(\.fixIt), to: pass.source),
        let restored = pass.source.unmasking(edited)
      else { break }
      fixed = restored
      pass = check(fixed, fileURL: fileURL)
    }
    return (diagnostics, fixed)
  }

  /// Runs every rule on `content` and returns the diagnostics that no
  /// directive turns off, together with the masked text they refer to.
  private func check(_ content: String, fileURL: URL) -> ([Diagnostic], MaskedSource) {
    let document = Document(parsing: content)
    let source = MaskedSource(content: content, document: document)
    let directives = DisableDirectives(document: document)
    var diagnostics: [Diagnostic] = []

    for rule in rules {
      let found = rule.check(document: document, fileURL: fileURL, originalText: source.text)
      diagnostics.append(
        contentsOf: found.filter { !directives.disables($0.ruleID, atLine: $0.line) })
    }
    return (diagnostics, source)
  }
}

// MARK: - Applying fix-its

extension Linter {
  /// Applies the fix-its that can be applied together to the masked text.
  ///
  /// - Parameters:
  ///   - fixIts: The fix-its, in the order in which their diagnostics were
  ///     reported.
  ///   - source: The masked text the fix-its refer to.
  /// - Returns: The edited masked text, or `nil` when no fix-it could be
  ///   applied.
  static func applying(_ fixIts: [FixIt], to source: MaskedSource) -> String? {
    guard !fixIts.isEmpty else { return nil }
    let maskedText = source.text
    let lines = LineIndex(maskedText)

    var edits: [(range: Range<String.Index>, replacement: String, order: Int)] = []
    for (order, fixIt) in fixIts.enumerated() {
      guard let range = range(of: fixIt, in: source, lines: lines) else { continue }
      edits.append((range, fixIt.replacement, order))
    }
    // Earlier text first. At the same position, the fix-it reported first,
    // which is the one of the earlier rule.
    edits.sort {
      $0.range.lowerBound != $1.range.lowerBound
        ? $0.range.lowerBound < $1.range.lowerBound : $0.order < $1.order
    }

    var result = ""
    var copiedUpTo = maskedText.startIndex
    var lastInsertion: String.Index?
    var applied = false
    for edit in edits {
      // An edit that overlaps the previous one waits for the next pass, and
      // so does a second insertion at the same position.
      guard edit.range.lowerBound >= copiedUpTo else { continue }
      if edit.range.isEmpty {
        guard lastInsertion != edit.range.lowerBound else { continue }
        lastInsertion = edit.range.lowerBound
      }
      result += maskedText[copiedUpTo..<edit.range.lowerBound]
      result += edit.replacement
      copiedUpTo = edit.range.upperBound
      applied = true
    }
    guard applied else { return nil }
    result += maskedText[copiedUpTo...]
    return result
  }

  /// Returns the range that a fix-it replaces, or `nil` when the fix-it must
  /// not be applied: its range does not exist, it would not change anything,
  /// or it touches code or raw HTML, which the mask hides.
  private static func range(of fixIt: FixIt, in source: MaskedSource, lines: LineIndex)
    -> Range<String.Index>?
  {
    guard
      let lowerBound = lines.index(line: fixIt.line, characterColumn: fixIt.column),
      let upperBound = lines.index(line: fixIt.endLine, characterColumn: fixIt.endColumn),
      lowerBound <= upperBound
    else { return nil }
    let range = lowerBound..<upperBound
    guard source.text[range] != fixIt.replacement,
      !source.isProtected(range, from: fixIt.replacement)
    else { return nil }
    return range
  }
}
