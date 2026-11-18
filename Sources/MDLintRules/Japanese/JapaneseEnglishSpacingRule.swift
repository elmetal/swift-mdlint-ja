import Foundation
import MDLintCore
import Markdown

/// A rule that removes superfluous spaces between Japanese and Latin text.
///
/// Full-width Japanese characters and adjacent ASCII words should appear
/// without separating spaces. The rule searches each line outside of code
/// blocks and inline code spans for whitespace that divides Japanese and
/// English segments and produces diagnostics with autofix replacements that
/// collapse the gap.
public struct JapaneseEnglishSpacingRule: Rule, AutoFixable {
  public let id = "ja.spacing.no-space-between-japanese-and-english"
  public let description = "和文と英単語の間にスペースは入れないでください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let codeLines = document.codeBlockLineNumbers
    let inlineCode = document.inlineCodeRanges(in: originalText)

    for (index, line) in originalText.sourceLines.enumerated()
    where !codeLines.contains(index + 1) {
      for spaces in Self.superfluousSpaces(in: line, inlineCode: inlineCode) {
        let diagnostic = Diagnostic(
          file: fileURL,
          line: index + 1,
          column: line.distance(from: line.startIndex, to: spaces.lowerBound) + 1,
          ruleID: id,
          message: "和文と英単語の間にスペースは入れないでください。",
          severity: .warning,
          fixIt: "スペースを削除")
        diagnostics.append(diagnostic)
      }
    }

    return diagnostics
  }

  public func fixing(originalText: String) -> String {
    let document = Document(parsing: originalText)
    let codeLines = document.codeBlockLineNumbers
    let inlineCode = document.inlineCodeRanges(in: originalText)

    return originalText.mappingSourceLines(skipping: codeLines) { line in
      var fixed = ""
      var copiedUpTo = line.startIndex
      for spaces in Self.superfluousSpaces(in: line, inlineCode: inlineCode) {
        fixed += line[copiedUpTo..<spaces.lowerBound]
        copiedUpTo = spaces.upperBound
      }
      fixed += line[copiedUpTo...]
      return fixed
    }
  }

  /// Returns the whitespace runs that separate Japanese and Latin text on the
  /// line, in order of appearance, leaving out those inside inline code spans.
  ///
  /// A whitespace run is preceded by exactly one character, so the two patterns
  /// can never claim the same run.
  private static func superfluousSpaces(in line: Substring, inlineCode: InlineCodeRanges)
    -> [Range<String.Index>]
  {
    [japaneseBeforeEnglishRegex, englishBeforeJapaneseRegex]
      .flatMap { regex in
        line.matches(of: regex).map { match in
          match.output.2.startIndex..<match.output.2.endIndex
        }
      }
      .filter { !inlineCode.contains($0.lowerBound) }
      .sorted { $0.lowerBound < $1.lowerBound }
  }

  private typealias SpacingRegex = Regex<(Substring, Substring, Substring, Substring)>

  // Regex is not Sendable, so these are computed rather than stored statics.
  private static var japaneseBeforeEnglishRegex: SpacingRegex {
    /([\p{Han}\p{Hiragana}\p{Katakana}々〆ヵヶ])([ \t]+)([A-Za-z])/
  }
  private static var englishBeforeJapaneseRegex: SpacingRegex {
    /([A-Za-z])([ \t]+)([\p{Han}\p{Hiragana}\p{Katakana}々〆ヵヶ])/
  }
}
