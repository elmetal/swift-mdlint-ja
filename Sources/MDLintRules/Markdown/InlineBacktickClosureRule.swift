import Foundation
import MDLintCore
import Markdown

/// A rule that ensures inline code spans use balanced backticks.
///
/// Inline code snippets must open and close with the same number of backtick
/// characters. Code spans recognized by the Markdown parser (including ones
/// that continue on the next line) and code blocks are skipped; any other
/// backtick run that has no closing run of the same length on its line is
/// reported.
public struct InlineBacktickClosureRule: Rule {
  public let id = "ja.backtick.unmatched"
  public let description = "インラインコードのバッククォートは閉じてください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let codeLines = document.codeBlockLineNumbers
    let inlineCode = document.inlineCodeRanges(in: originalText)

    for (index, line) in originalText.sourceLines.enumerated()
    where !codeLines.contains(index + 1) {
      if let unmatched = BacktickScanner.scan(line, skipping: inlineCode).firstUnmatched {
        let diagnostic = Diagnostic(
          file: fileURL,
          line: index + 1,
          column: line.distance(from: line.startIndex, to: unmatched) + 1,
          ruleID: id,
          message: "インラインコードのバッククォートが閉じられていません。"
        )
        diagnostics.append(diagnostic)
      }
    }

    return diagnostics
  }
}
