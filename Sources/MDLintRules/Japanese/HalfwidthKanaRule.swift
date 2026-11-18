import Foundation
import MDLintCore
import Markdown

/// A rule that flags the presence of half-width Katakana characters.
///
/// Japanese writing guidelines generally discourage the use of half-width
/// Katakana in prose. This rule scans the Markdown text line by line and
/// reports diagnostics for any half-width Katakana characters that it
/// encounters. The linter hides code and raw HTML before the rule runs.
public struct HalfwidthKanaRule: Rule {
  public let id = "ja.kana.no-halfwidth"
  public let description = "半角カナは使用しないでください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    for (lineIndex, line) in originalText.sourceLines.enumerated() {
      // Columns count characters, as in every other rule. A kana and its half-width
      // voiced sound mark, as in "ｶﾞ", form one character and are reported once.
      for (columnOffset, character) in line.enumerated() {
        if character.unicodeScalars.contains(where: isHalfwidthKana) {
          let column = columnOffset + 1
          let diagnostic = Diagnostic(
            file: fileURL,
            line: lineIndex + 1,
            column: column,
            ruleID: id,
            message: "半角カナ（\(character)）は使用せず、全角カナを利用してください。",
            severity: .warning,
            fixIt: nil
          )
          diagnostics.append(diagnostic)
        }
      }
    }

    return diagnostics
  }

  private func isHalfwidthKana(_ scalar: Unicode.Scalar) -> Bool {
    // Unicode range U+FF61 ... U+FF9F represents half-width Katakana.
    return scalar.value >= 0xFF61 && scalar.value <= 0xFF9F
  }
}
