import Foundation
import MDLintCore
import Markdown

/// A rule that enforces a maximum sentence length of 100 characters, excluding URLs.
///
/// Long sentences can reduce readability. This rule counts characters in each sentence
/// while ignoring URL substrings and reports a diagnostic when the length exceeds 100.
/// A sentence ends at a terminator such as "。", at a blank line (a paragraph break),
/// or at a code block; the contents of code blocks are not counted.
public struct SentenceLengthLimitRule: Rule {
  public let id = "ja.sentence.max-one-hundred-characters"
  public let description = "URL を除いて一文は100文字以内にしてください。"

  private let sentenceTerminators: Set<Character> = ["。", "！", "？", "!", "?", "．"]
  private let maxLength = 100

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    let urlRanges = Self.urlRanges(in: originalText)

    var currentURLRangeIndex = 0

    var diagnostics: [Diagnostic] = []

    var line = 1
    var column = 1

    var currentLength = 0
    var exceeded = false
    var exceedingLine: Int?
    var exceedingColumn: Int?
    var lineIsBlank = true
    let codeLines = document.codeBlockLineNumbers
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
        "一文が101文字以上になっています（現在の文字数: \(currentSentenceLength)）。URL を除いて100文字以内に収まるように文を見直してください。"
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

      if !isInURL && !isMaskedBlock {
        currentLength += 1
        if currentLength == maxLength + 1 {
          exceeded = true
          exceedingLine = line
          exceedingColumn = column
        }
      }

      if isMaskedBlock || sentenceTerminators.contains(character) {
        endSentence()
      }

      if character.isLineTerminator {
        // A blank line separates paragraphs, so no sentence continues across it.
        if lineIsBlank { endSentence() }
        line += 1
        column = 1
        lineIsBlank = true
        inCodeBlock = codeLines.contains(line)
        // A code block interrupts the paragraph it follows.
        if inCodeBlock { endSentence() }
      } else {
        column += 1
        if !character.isWhitespace { lineIsBlank = false }
      }
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
