import Foundation
import MDLintCore
import Markdown

/// A rule that flags the presence of half-width Katakana characters.
///
/// Japanese writing guidelines generally discourage the use of half-width
/// Katakana in prose. This rule scans the original Markdown text line by line,
/// skipping code blocks and inline code spans, and reports diagnostics for any
/// half-width Katakana characters that it encounters.
public struct HalfwidthKanaRule: Rule {
  public let id = "ja.kana.no-halfwidth"
  public let description = "半角カナは使用しないでください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let codeLines = document.codeBlockLineNumbers
    let inlineCode = document.inlineCodeRanges(in: originalText)

    for (lineIndex, line) in originalText.sourceLines.enumerated()
    where !codeLines.contains(lineIndex + 1) {
      let scalars = line.unicodeScalars
      for (columnOffset, scalarIndex) in scalars.indices.enumerated() {
        let scalar = scalars[scalarIndex]
        if isHalfwidthKana(scalar), !inlineCode.contains(scalarIndex) {
          let column = columnOffset + 1
          let character = String(scalar)
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
