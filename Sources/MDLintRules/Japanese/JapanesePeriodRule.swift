import Foundation
import MDLintCore
import Markdown

/// A rule that standardizes sentence-ending punctuation to "。".
///
/// Japanese prose typically concludes sentences with the full-width "。"
/// character. The rule reviews each line of Markdown text outside of code
/// blocks and raises a diagnostic—along with an autofix suggestion—whenever it
/// finds a line that ends in a half-width period.
public struct JapanesePeriodRule: Rule, AutoFixable {
  public let id = "ja.period.prefer-fullwidth"
  public let description = "文末の終止符は「。」に統一してください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var out: [Diagnostic] = []

    // 単純化: 行単位で見る。コードブロック以外の行で、末尾の "." または "．" を検出
    let codeLines = document.codeBlockLineNumbers
    for (i, line) in originalText.sourceLines.enumerated() where !codeLines.contains(i + 1) {
      guard let index = Self.terminalPeriodIndex(in: line) else { continue }
      let period = line[index]
      let d = Diagnostic(
        file: fileURL,
        line: i + 1,
        column: line.distance(from: line.startIndex, to: index) + 1,
        ruleID: id,
        message: "文末は「。」に統一しましょう（現在: \(period)）。",
        severity: .warning,
        fixIt: "末尾の \(period) を「。」に置換")
      out.append(d)
    }
    return out
  }

  public func fixing(originalText: String) -> String {
    let codeLines = Document(parsing: originalText).codeBlockLineNumbers
    return originalText.mappingSourceLines(skipping: codeLines) { line in
      guard let index = Self.terminalPeriodIndex(in: line) else { return String(line) }
      // 行末の "."/ "．" を "。" に置換し、後続の空白は保持する
      return line[..<index] + "。" + line[line.index(after: index)...]
    }
  }

  /// Returns the index of a "." or "．" that ends the line, ignoring trailing whitespace.
  private static func terminalPeriodIndex(in line: Substring) -> String.Index? {
    guard let index = line.lastIndex(where: { !$0.isWhitespace }) else { return nil }
    return line[index] == "." || line[index] == "．" ? index : nil
  }
}
