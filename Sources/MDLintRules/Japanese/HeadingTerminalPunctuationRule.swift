import Foundation
import MDLintCore
import Markdown

/// A rule that removes terminal punctuation from Markdown headings.
///
/// Headings should present concise labels that end without punctuation such as
/// "。", "．", ".", "、", or ",". This rule inspects each heading node in the
/// parsed document and raises a diagnostic, offering an autofix that strips the
/// trailing punctuation character when one is found.
///
/// Both the check and the autofix locate headings through the parsed document,
/// so lines that merely start with `#` (for example comments inside code
/// blocks) are left alone.
public struct HeadingTerminalPunctuationRule: Rule, AutoFixable {
  public let id = "ja.heading.no-terminal-punctuation"
  public let description = "見出し（# ...）の末尾に句読点は付けないでください。"

  private static let forbidden: Set<Character> = ["。", "．", ".", "、", ","]

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    Self.terminalPunctuation(in: document, originalText: originalText).map { occurrence in
      Diagnostic(
        file: fileURL,
        line: occurrence.line,
        column: occurrence.column,
        ruleID: id,
        message: "見出し末尾の句読点「\(originalText[occurrence.index])」を削除してください。",
        severity: .warning,
        fixIt: "末尾の句読点を除去")
    }
  }

  public func fixing(originalText: String) -> String {
    let document = Document(parsing: originalText)
    let occurrences = Self.terminalPunctuation(in: document, originalText: originalText)
    guard !occurrences.isEmpty else { return originalText }

    var fixed = ""
    var copiedUpTo = originalText.startIndex
    for occurrence in occurrences.sorted(by: { $0.index < $1.index }) {
      fixed += originalText[copiedUpTo..<occurrence.index]
      copiedUpTo = originalText.index(after: occurrence.index)
    }
    fixed += originalText[copiedUpTo...]
    return fixed
  }

  private struct Occurrence {
    let index: String.Index
    let line: Int
    let column: Int
  }

  /// Finds the terminal punctuation character of every heading in the document.
  private static func terminalPunctuation(in document: Document, originalText: String)
    -> [Occurrence]
  {
    let lines = originalText.sourceLines
    var occurrences: [Occurrence] = []

    forEachHeading(in: document) { heading in
      // The heading ends with punctuation only when its last inline leaf is text;
      // a trailing code span or image is not prose.
      guard
        let text = lastTextLeaf(of: heading),
        let last = text.string.last, forbidden.contains(last),
        let end = text.range?.upperBound,
        lines.indices.contains(end.line - 1)
      else { return }

      // Source columns are 1-based UTF-8 offsets and the upper bound is exclusive,
      // so the punctuation is the character that ends right before it.
      let line = lines[end.line - 1]
      guard
        let endIndex = line.utf8.index(
          line.startIndex, offsetBy: end.column - 1, limitedBy: line.endIndex),
        endIndex > line.startIndex
      else { return }
      let index = line.index(before: endIndex)
      // Skip when the source does not match (escapes or entities shift positions).
      guard line[index] == last else { return }

      occurrences.append(
        Occurrence(
          index: index,
          line: end.line,
          column: line.distance(from: line.startIndex, to: index) + 1))
    }
    return occurrences
  }

  private static func forEachHeading(in markup: Markup, _ body: (Heading) -> Void) {
    for child in markup.children {
      if let heading = child as? Heading {
        body(heading)
      } else if child is BlockMarkup {
        forEachHeading(in: child, body)
      }
    }
  }

  private static func lastTextLeaf(of markup: Markup) -> Text? {
    guard markup.childCount > 0, let last = markup.child(at: markup.childCount - 1) else {
      return nil
    }
    if let text = last as? Text { return text }
    if last is InlineCode || last is Image { return nil }
    return lastTextLeaf(of: last)
  }
}
