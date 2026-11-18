import Foundation
import Markdown

/// Markdown source text in which everything that is not prose is replaced by
/// placeholder characters.
///
/// Lint rules are meant to inspect prose, not code. ``MaskedSource`` hides the
/// following regions of a document so that rules neither report nor rewrite
/// them:
///
/// - Fenced and indented code blocks, and HTML blocks. Each hidden character
///   becomes ``blockPlaceholder``.
/// - Inline code spans and inline HTML. Each hidden character becomes
///   ``inlinePlaceholder``.
///
/// Every hidden character is replaced by exactly one placeholder character and
/// line breaks are kept, so a line and column in ``text`` refers to the same
/// position in the original source.
///
/// After automatic fixes have edited ``text``, call ``unmasking(_:)`` to put
/// the hidden characters back.
public struct MaskedSource: Sendable {
  /// The character that stands in for one hidden character of inline code or
  /// inline HTML (U+FFFC OBJECT REPLACEMENT CHARACTER).
  public static let inlinePlaceholder: Character = "\u{FFFC}"

  /// The character that stands in for one hidden character of a code block or
  /// an HTML block (U+E000, a private-use character).
  ///
  /// A masked block is never part of a sentence, so rules that work sentence
  /// by sentence should treat this character as a sentence boundary.
  public static let blockPlaceholder: Character = "\u{E000}"

  /// The source text with all non-prose regions replaced by placeholders.
  public let text: String

  /// The hidden characters in document order, each paired with the placeholder
  /// that replaced it.
  private let hidden: [Hidden]

  private struct Hidden: Sendable {
    let placeholder: Unicode.Scalar
    let original: Character
  }

  /// Masks the non-prose regions of a Markdown document.
  ///
  /// - Parameters:
  ///   - content: The original Markdown source.
  ///   - document: The document parsed from `content`. Its source ranges
  ///     decide which regions are hidden.
  public init(content: String, document: Document) {
    let regions = Self.regions(in: document, of: content)

    var masked = ""
    var hidden: [Hidden] = []

    // A placeholder character that already occurs in the prose is recorded as
    // hiding itself, so that `unmasking(_:)` stays unambiguous.
    func appendVisible(_ slice: Substring) {
      for scalar in slice.unicodeScalars {
        if Self.isPlaceholder(scalar) {
          hidden.append(Hidden(placeholder: scalar, original: Character(scalar)))
        }
        masked.unicodeScalars.append(scalar)
      }
    }

    var cursor = content.startIndex
    for region in regions {
      appendVisible(content[cursor..<region.range.lowerBound])
      let placeholder = region.placeholder.unicodeScalars.first!
      for character in content[region.range] {
        if character.isNewline {
          masked.append(character)
        } else {
          masked.unicodeScalars.append(placeholder)
          hidden.append(Hidden(placeholder: placeholder, original: character))
        }
      }
      cursor = region.range.upperBound
    }
    appendVisible(content[cursor...])

    self.text = masked
    self.hidden = hidden
  }

  /// Restores the hidden characters in an edited copy of ``text``.
  ///
  /// The edited text must still contain every placeholder, in the original
  /// order. Everything between the placeholders may have changed.
  ///
  /// - Parameter maskedText: ``text``, possibly modified by automatic fixes.
  /// - Returns: The text with each placeholder replaced by the character it
  ///   hides, or `nil` when placeholders were added, removed, or reordered.
  public func unmasking(_ maskedText: String) -> String? {
    var restored = String.UnicodeScalarView()
    var next = hidden.startIndex

    for scalar in maskedText.unicodeScalars {
      guard Self.isPlaceholder(scalar) else {
        restored.append(scalar)
        continue
      }
      guard next < hidden.endIndex, hidden[next].placeholder == scalar else { return nil }
      restored.append(contentsOf: hidden[next].original.unicodeScalars)
      next += 1
    }

    guard next == hidden.endIndex else { return nil }
    return String(restored)
  }

  private static func isPlaceholder(_ scalar: Unicode.Scalar) -> Bool {
    inlinePlaceholder.unicodeScalars.first == scalar
      || blockPlaceholder.unicodeScalars.first == scalar
  }
}

// MARK: - Finding the regions to hide

extension MaskedSource {
  private struct Region {
    let range: Range<String.Index>
    let placeholder: Character
  }

  /// Returns the regions to hide, in document order and without overlaps.
  private static func regions(in document: Document, of content: String) -> [Region] {
    let lines = LineIndex(content)
    var regions: [Region] = []
    // The end of the last region found so far. Nodes are visited in source
    // order, so the next region can only start here or later.
    var cursor = content.startIndex

    func add(_ range: Range<String.Index>, as placeholder: Character) {
      let lowerBound = max(range.lowerBound, cursor)
      guard lowerBound < range.upperBound else { return }
      regions.append(Region(range: lowerBound..<range.upperBound, placeholder: placeholder))
      cursor = range.upperBound
    }

    // The parser reports correct lines for inline nodes, but its columns are
    // wrong in several situations: after the first line of an indented
    // paragraph, at the end of a node that continues on the next line, and
    // after an escaped pipe in a table cell. Inline nodes are therefore found
    // by searching their lines for their text. If that fails, the rest of
    // those lines is hidden, because hiding prose is safer than exposing code
    // to automatic fixes.
    func addInline(_ markup: Markup, locate: (Range<String.Index>) -> Range<String.Index>?) {
      guard let sourceRange = markup.range,
        let lineRange = lines.range(
          ofLines: sourceRange.lowerBound.line...sourceRange.upperBound.line)
      else { return }
      let lowerBound = max(lineRange.lowerBound, cursor)
      guard lowerBound < lineRange.upperBound else { return }
      let searchRange = lowerBound..<lineRange.upperBound
      add(locate(searchRange) ?? searchRange, as: inlinePlaceholder)
    }

    func visit(_ markup: Markup) {
      switch markup {
      case is CodeBlock, is HTMLBlock:
        guard let sourceRange = markup.range else { return }
        if let lowerBound = lines.index(of: sourceRange.lowerBound),
          let upperBound = lines.index(of: sourceRange.upperBound),
          lowerBound < upperBound
        {
          add(lowerBound..<upperBound, as: blockPlaceholder)
        } else {
          // Unusable columns: hide the block's lines entirely. An end at
          // column 1 means the block stops before that line.
          let end = sourceRange.upperBound
          let lastLine = end.column == 1 ? end.line - 1 : end.line
          if lastLine >= sourceRange.lowerBound.line,
            let lineRange = lines.range(ofLines: sourceRange.lowerBound.line...lastLine)
          {
            add(lineRange, as: blockPlaceholder)
          }
        }
      case let code as InlineCode:
        addInline(code) { codeSpan(containing: code.code, in: content, within: $0) }
      case let html as InlineHTML:
        addInline(html) { occurrence(of: html.rawHTML, in: content, within: $0) }
      default:
        for child in markup.children { visit(child) }
      }
    }

    visit(document)
    return regions
  }

  /// Finds the code span whose content is `code`, delimiters included.
  private static func codeSpan(
    containing code: String, in content: String, within range: Range<String.Index>
  ) -> Range<String.Index>? {
    let expected = code.filter { !$0.isWhitespace }

    func endOfBacktickRun(at start: String.Index) -> String.Index {
      var end = start
      while end < range.upperBound, content[end] == "`" { end = content.index(after: end) }
      return end
    }

    var index = range.lowerBound
    while index < range.upperBound {
      guard content[index] == "`" else {
        index = content.index(after: index)
        continue
      }
      // A code span ends at the next backtick run of the same length.
      let openingEnd = endOfBacktickRun(at: index)
      if let contentEnd = end(of: expected, in: content, from: openingEnd, upTo: range.upperBound) {
        let closingStart = skippingSourceOnlyCharacters(
          in: content, from: contentEnd, upTo: range.upperBound)
        let closingEnd = endOfBacktickRun(at: closingStart)
        if content.distance(from: closingStart, to: closingEnd)
          == content.distance(from: index, to: openingEnd)
        {
          return index..<closingEnd
        }
      }
      index = openingEnd
    }
    return nil
  }

  /// Finds the first place where the source spells out `text`.
  private static func occurrence(
    of text: String, in content: String, within range: Range<String.Index>
  ) -> Range<String.Index>? {
    let expected = text.filter { !$0.isWhitespace }
    guard let first = expected.first else { return nil }

    var index = range.lowerBound
    while index < range.upperBound {
      if content[index] == first,
        let end = end(of: expected, in: content, from: index, upTo: range.upperBound)
      {
        return index..<end
      }
      index = content.index(after: index)
    }
    return nil
  }

  /// Returns the index just past `expected` when the source spells it out
  /// starting at `start`, or `nil` when it does not.
  ///
  /// `expected` is text as the parser reports it, with whitespace removed. The
  /// source may differ from it in whitespace, in the block quote markers and
  /// indentation at the start of continuation lines, and in the backslash of
  /// an escaped pipe inside a table cell.
  private static func end(
    of expected: String, in content: String, from start: String.Index, upTo limit: String.Index
  ) -> String.Index? {
    var remaining = expected[...]
    var index = start
    var isInLinePrefix = false

    while let next = remaining.first {
      guard index < limit else { return nil }
      let character = content[index]
      let following = content.index(after: index)

      if character == next {
        remaining.removeFirst()
        isInLinePrefix = false
      } else if character.isNewline {
        isInLinePrefix = true
      } else if character.isWhitespace || (isInLinePrefix && character == ">") {
        // Not part of the parsed text.
      } else if character == "\\", following < limit, content[following] == "|" {
        // Not part of the parsed text.
      } else {
        return nil
      }
      index = following
    }
    return index
  }

  /// Skips whitespace and the block quote markers at the start of
  /// continuation lines.
  private static func skippingSourceOnlyCharacters(
    in content: String, from start: String.Index, upTo limit: String.Index
  ) -> String.Index {
    var index = start
    var isInLinePrefix = false
    while index < limit {
      let character = content[index]
      if character.isNewline {
        isInLinePrefix = true
      } else if !(character.isWhitespace || (isInLinePrefix && character == ">")) {
        break
      }
      index = content.index(after: index)
    }
    return index
  }
}

/// Converts the line and column pairs reported by the Markdown parser into
/// string indices.
private struct LineIndex {
  private let text: String
  /// The index of the first character of each line.
  private let lineStarts: [String.Index]

  init(_ text: String) {
    self.text = text

    // The parser ends a line at LF, CRLF, or a lone CR.
    let utf8 = text.utf8
    var lineStarts = [utf8.startIndex]
    var index = utf8.startIndex
    while index < utf8.endIndex {
      let byte = utf8[index]
      let next = utf8.index(after: index)
      if byte == UInt8(ascii: "\n") {
        lineStarts.append(next)
      } else if byte == UInt8(ascii: "\r"),
        next == utf8.endIndex || utf8[next] != UInt8(ascii: "\n")
      {
        lineStarts.append(next)
      }
      index = next
    }
    self.lineStarts = lineStarts
  }

  /// Returns the string index of a parser location, whose column counts UTF-8
  /// bytes starting from 1. Returns `nil` when the location does not fall on
  /// a character boundary inside its line.
  func index(of location: SourceLocation) -> String.Index? {
    guard let lineRange = range(ofLines: location.line...location.line), location.column >= 1
    else { return nil }
    let utf8 = text.utf8
    guard
      let index = utf8.index(
        lineRange.lowerBound, offsetBy: location.column - 1, limitedBy: lineRange.upperBound)
    else {
      return nil
    }
    return index.samePosition(in: text.unicodeScalars)
  }

  /// Returns the range that covers the given 1-based lines, line breaks
  /// included.
  func range(ofLines lineNumbers: ClosedRange<Int>) -> Range<String.Index>? {
    guard lineNumbers.lowerBound >= 1, lineNumbers.upperBound <= lineStarts.count else {
      return nil
    }
    let upperBound =
      lineNumbers.upperBound < lineStarts.count
      ? lineStarts[lineNumbers.upperBound] : text.endIndex
    return lineStarts[lineNumbers.lowerBound - 1]..<upperBound
  }
}
