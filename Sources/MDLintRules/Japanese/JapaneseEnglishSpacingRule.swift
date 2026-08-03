import Foundation
import MDLintCore
import Markdown

/// A rule that removes superfluous spaces between Japanese and Latin text.
///
/// Full-width Japanese characters and adjacent ASCII words should appear
/// without separating spaces. The rule searches each line for whitespace that
/// divides Japanese and English segments and produces diagnostics with autofix
/// replacements that collapse the gap.
public struct JapaneseEnglishSpacingRule: Rule, AutoFixable {
  public let id = "ja.spacing.no-space-between-japanese-and-english"
  public let description = "和文と英単語の間にスペースは入れないでください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let lines = originalText.components(separatedBy: "\n")
    let regexes = [Self.japaneseBeforeEnglishRegex, Self.englishBeforeJapaneseRegex]

    for (index, line) in lines.enumerated() {
      diagnostics.append(
        contentsOf: diagnosticsForLine(
          line, lineNumber: index + 1, fileURL: fileURL, regexes: regexes))
    }

    return diagnostics
  }

  public func fixing(originalText: String) -> String {
    var fixed = originalText
    fixed = Self.removingSpaces(matchedBy: Self.japaneseBeforeEnglishRegex, in: fixed)
    fixed = Self.removingSpaces(matchedBy: Self.englishBeforeJapaneseRegex, in: fixed)
    return fixed
  }

  private func diagnosticsForLine(
    _ line: String, lineNumber: Int, fileURL: URL, regexes: [SpacingRegex]
  ) -> [Diagnostic] {
    var result: [Diagnostic] = []

    for regex in regexes {
      for match in line.matches(of: regex) {
        let spaces = match.output.2
        let column = line.distance(from: line.startIndex, to: spaces.startIndex) + 1
        let diagnostic = Diagnostic(
          file: fileURL,
          line: lineNumber,
          column: column,
          ruleID: id,
          message: "和文と英単語の間にスペースは入れないでください。",
          severity: .warning,
          fixIt: "スペースを削除")
        result.append(diagnostic)
      }
    }

    return result
  }

  private typealias SpacingRegex = Regex<(Substring, Substring, Substring, Substring)>

  // Regex is not Sendable, so these are computed rather than stored statics.
  private static var japaneseBeforeEnglishRegex: SpacingRegex {
    /([\p{Han}\p{Hiragana}\p{Katakana}々〆ヵヶ])([ \t]+)([A-Za-z])/
  }
  private static var englishBeforeJapaneseRegex: SpacingRegex {
    /([A-Za-z])([ \t]+)([\p{Han}\p{Hiragana}\p{Katakana}々〆ヵヶ])/
  }

  private static func removingSpaces(matchedBy regex: SpacingRegex, in text: String) -> String {
    text.replacing(regex) { match in
      "\(match.output.1)\(match.output.3)"
    }
  }
}
