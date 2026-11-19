import Foundation
import MDLintCore
import Markdown

/// A rule that removes terminal punctuation from Markdown headings.
///
/// Headings should present concise labels that end without punctuation such as
/// "。", "．", ".", "、", or ",". This rule inspects each heading node in the
/// parsed document and raises a diagnostic with a fix-it that deletes the
/// trailing punctuation character when one is found.
///
/// Headings are located through the parsed document, so lines that merely
/// start with `#` (for example comments inside code blocks) are left alone.
public struct HeadingTerminalPunctuationRule: Rule {
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
        fixIt: FixIt(
          description: "末尾の句読点を除去",
          line: occurrence.line,
          column: occurrence.column,
          endLine: occurrence.line,
          endColumn: occurrence.column + 1,
          replacement: ""))
    }
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
    // The lines on which a heading ends in punctuation and which hold hidden text.
    var linesWithHiddenText: Set<Int> = []

    forEachTerminalPunctuation(in: document, lines: lines) { punctuation, end, line in
      if line.unicodeScalars.contains(where: isPlaceholder) {
        linesWithHiddenText.insert(end.line)
      } else if let occurrence = occurrence(of: punctuation, endingAt: end, in: line) {
        occurrences.append(occurrence)
      }
    }
    guard !linesWithHiddenText.isEmpty else { return occurrences }

    // The parser's columns count the bytes of the real source. They do not
    // apply to a line with hidden text, where a placeholder takes a different
    // number of bytes than the character it stands for. Parsing the masked
    // text gives columns that do. Only the headings found in the real source
    // are looked up this way, since masking can change the block structure.
    let maskedDocument = Document(parsing: originalText)
    forEachTerminalPunctuation(in: maskedDocument, lines: lines) { punctuation, end, line in
      guard linesWithHiddenText.contains(end.line),
        let occurrence = occurrence(of: punctuation, endingAt: end, in: line)
      else { return }
      occurrences.append(occurrence)
    }
    return occurrences.sorted { $0.index < $1.index }
  }

  /// Calls `body` for every heading whose last piece of text ends in forbidden
  /// punctuation, with the punctuation character, the parser's position just
  /// past it, and the line of `lines` that the position is on.
  private static func forEachTerminalPunctuation(
    in document: Document, lines: [Substring],
    _ body: (Character, SourceLocation, Substring) -> Void
  ) {
    forEachHeading(in: document) { heading in
      // The heading ends with punctuation only when its last inline leaf is text;
      // a trailing code span or image is not prose.
      guard
        let text = lastTextLeaf(of: heading),
        let last = text.string.last, forbidden.contains(last),
        let end = text.range?.upperBound,
        lines.indices.contains(end.line - 1)
      else { return }
      body(last, end, lines[end.line - 1])
    }
  }

  /// Locates the punctuation character that ends right before `end` on `line`.
  private static func occurrence(
    of punctuation: Character, endingAt end: SourceLocation, in line: Substring
  ) -> Occurrence? {
    // Source columns are 1-based UTF-8 offsets and the upper bound is exclusive,
    // so the punctuation is the character that ends right before it.
    guard
      let endIndex = line.utf8.index(
        line.startIndex, offsetBy: end.column - 1, limitedBy: line.endIndex),
      endIndex > line.startIndex,
      // A column inside a character does not belong to this line's text.
      let alignedEnd = endIndex.samePosition(in: line.base.unicodeScalars)
    else { return nil }
    let index = line.index(before: alignedEnd)
    // Skip when the source does not match (escapes or entities shift positions).
    guard line[index] == punctuation else { return nil }

    return Occurrence(
      index: index,
      line: end.line,
      column: line.distance(from: line.startIndex, to: index) + 1)
  }

  private static func isPlaceholder(_ scalar: Unicode.Scalar) -> Bool {
    MaskedSource.inlinePlaceholder.unicodeScalars.first == scalar
      || MaskedSource.blockPlaceholder.unicodeScalars.first == scalar
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
