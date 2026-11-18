import Foundation
import MDLintCore
import Markdown

/// A rule that enforces a maximum sentence length of 100 characters, excluding URLs
/// and code.
///
/// Long sentences can reduce readability. This rule counts characters in each sentence
/// while ignoring URL substrings and inline code spans, and reports a diagnostic when the
/// length exceeds 100. A sentence ends at a terminator such as "。", at a blank line (a
/// paragraph break), or at a code block; the contents of code blocks are not counted.
///
/// A sentence also ends where the next block begins, so list items, headings, and table
/// rows that follow each other without a blank line are separate sentences, and so is each
/// cell of a table. An ASCII period ends a sentence when whitespace or the end of the line
/// follows it, which keeps an English paragraph from being measured as a single sentence.
public struct SentenceLengthLimitRule: Rule {
  public let id = "ja.sentence.max-one-hundred-characters"
  public let description = "URL とコードを除いて一文は100文字以内にしてください。"

  private let sentenceTerminators: Set<Character> = ["。", "！", "？", "!", "?", "．"]
  private let maxLength = 100

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    let urlRanges = Self.urlRanges(in: originalText)

    var currentURLRangeIndex = 0

    var diagnostics: [Diagnostic] = []
    let sentenceBreaks = document.sentenceBreaks
    var previousCharacter: Character?

    var line = 1
    var column = 1

    var currentLength = 0
    var exceeded = false
    var exceedingLine: Int?
    var exceedingColumn: Int?
    var lineIsBlank = true
    let codeLines = document.codeBlockLineNumbers
    let inlineCode = document.inlineCodeRanges(in: originalText)
    var inCodeBlock = codeLines.contains(line)

    func endSentence() {
      let currentSentenceLength = currentLength
      defer {
        currentLength = 0
        exceeded = false
        exceedingLine = nil
        exceedingColumn = nil
      }
      guard exceeded,
        let diagnosticLine = exceedingLine,
        let diagnosticColumn = exceedingColumn
      else {
        return
      }

      let message =
        "一文が101文字以上になっています（現在の文字数: \(currentSentenceLength)）。URL とコードを除いて100文字以内に収まるように文を見直してください。"
      let diagnostic = Diagnostic(
        file: fileURL,
        line: diagnosticLine,
        column: diagnosticColumn,
        ruleID: id,
        message: message,
        severity: .warning,
        fixIt: nil
      )
      diagnostics.append(diagnostic)
    }

    var index = originalText.startIndex
    while index < originalText.endIndex {
      let character = originalText[index]
      let nextIndex = originalText.index(after: index)
      defer { index = nextIndex }

      if inCodeBlock {
        if character.isLineTerminator {
          line += 1
          column = 1
          inCodeBlock = codeLines.contains(line)
        }
        continue
      }

      while currentURLRangeIndex < urlRanges.count
        && index >= urlRanges[currentURLRangeIndex].upperBound
      {
        currentURLRangeIndex += 1
      }

      let isInURL: Bool
      if currentURLRangeIndex < urlRanges.count {
        let range = urlRanges[currentURLRangeIndex]
        isInURL = index >= range.lowerBound && index < range.upperBound
      } else {
        isInURL = false
      }

      // A masked code or HTML block is not part of any sentence: it ends the
      // sentence that precedes it and is not counted itself.
      let isMaskedBlock = character == MaskedSource.blockPlaceholder

      // Inline code is part of the sentence, but its contents are not prose:
      // they are neither counted nor able to end the sentence. The linter hands
      // over inline code and inline HTML already masked, one placeholder per
      // hidden character.
      let isInInlineCode =
        character == MaskedSource.inlinePlaceholder || inlineCode.contains(index)

      if !isInURL && !isMaskedBlock && !isInInlineCode {
        currentLength += 1
        if currentLength == maxLength + 1 {
          exceeded = true
          exceedingLine = line
          exceedingColumn = column
        }
      }

      if isMaskedBlock || (!isInInlineCode && sentenceTerminators.contains(character)) {
        endSentence()
      }

      if character.isLineTerminator {
        // A blank line separates paragraphs, so no sentence continues across it. Nor does
        // one continue into the next block.
        if lineIsBlank || sentenceBreaks.startsBlock(atLine: line + 1) { endSentence() }
        line += 1
        column = 1
        lineIsBlank = true
        inCodeBlock = codeLines.contains(line)
        // A code block interrupts the paragraph it follows.
        if inCodeBlock { endSentence() }
      } else {
        column += 1
        if !character.isWhitespace { lineIsBlank = false }
        // An ASCII period ends the sentence only when whitespace follows it, which keeps
        // "v1.2" and "example.com" in one piece.
        let isTerminalPeriod =
          character == "."
          && (nextIndex == originalText.endIndex || originalText[nextIndex].isWhitespace)
        if isTerminalPeriod
          || sentenceBreaks.separatesTableCells(character, after: previousCharacter, onLine: line)
        {
          endSentence()
        }
      }
      previousCharacter = character
    }

    endSentence()

    return diagnostics
  }
}

extension SentenceLengthLimitRule {
  /// Returns the ranges of URL substrings inside `text` using a lightweight regular expression.
  ///
  /// `NSDataDetector` is unavailable on Linux, so we approximate link detection with an
  /// RFC-3986-inspired expression that accepts any valid URL scheme.
  /// The ranges are returned in ascending order and can be used directly during scanning.
  static func urlRanges(in text: String) -> [Range<String.Index>] {
    let regex = /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^\s<>()\[\]{}\u{3000}]+/
    return text.ranges(of: regex)
  }
}
