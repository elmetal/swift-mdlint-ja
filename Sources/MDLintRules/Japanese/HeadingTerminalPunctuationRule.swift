import Foundation
import MDLintCore
import Markdown

/// A rule that removes terminal punctuation from Markdown headings.
///
/// Headings should present concise labels that end without punctuation such as
/// "。", "．", ".", "、", or ",". This rule scans each heading node in a parsed
/// document and raises a diagnostic, offering an autofix that strips the trailing
/// punctuation character when one is found.
public struct HeadingTerminalPunctuationRule: Rule, AutoFixable {
  public let id = "ja.heading.no-terminal-punctuation"
  public let description = "見出し（# ...）の末尾に句読点は付けないでください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var out: [Diagnostic] = []

    for block in document.blockChildren {
      guard let heading = block as? Heading else { continue }
      let text = heading.plainText
      guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else { continue }
      if ["。", "．", ".", "、", ","].contains(String(last)) {
        // 近似: ドキュメント先頭から heading のテキストを探す（最初の一致）
        guard let range = originalText.firstRange(of: text) else { continue }
        let (line, col) = lineColumn(in: originalText, before: range.upperBound)
        let d = Diagnostic(
          file: fileURL,
          line: line,
          column: col,
          ruleID: id,
          message: "見出し末尾の句読点「\(last)」を削除してください。",
          severity: .warning,
          fixIt: "末尾の句読点を除去")
        out.append(d)
      }
    }
    return out
  }

  public func fixing(originalText: String) -> String {
    let lines = originalText.components(separatedBy: "\n")
    var newLines: [String] = []
    for line in lines {
      if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
        var trimmedRight = line.rstripSpaces()
        let forbidden = ["。", "．", ".", "、", ","]
        if let last = trimmedRight.last, forbidden.contains(String(last)) {
          trimmedRight.removeLast()
          newLines.append(trimmedRight)
          continue
        }
      }
      newLines.append(line)
    }
    return newLines.joined(separator: "\n")
  }
}

private func lineColumn(in text: String, before index: String.Index) -> (Int, Int) {
  var line = 1
  var col = 1
  for ch in text[..<index] {
    if ch == "\n" {
      line += 1
      col = 1
    } else {
      col += 1
    }
  }
  return (line, col)
}

extension String {
  fileprivate func rstripSpaces() -> String {
    var s = self
    while s.last == " " || s.last == "\t" { s.removeLast() }
    return s
  }
}

extension Heading {
  fileprivate var plainText: String {
    self.plainTextInlines()
  }
  fileprivate func plainTextInlines() -> String {
    self.children.compactMap { inline -> String? in
      if let text = inline as? Text { return text.string }
      if let code = inline as? InlineCode { return code.code }
      if let strong = inline as? Strong {
        return strong.children.compactMap { ($0 as? Text)?.string }.joined()
      }
      if let em = inline as? Emphasis {
        return em.children.compactMap { ($0 as? Text)?.string }.joined()
      }
      return nil
    }.joined()
  }
}
