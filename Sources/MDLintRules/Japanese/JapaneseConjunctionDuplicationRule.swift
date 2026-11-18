import Foundation
import MDLintCore
import Markdown

/// A rule that detects back-to-back Japanese conjunctions.
///
/// Consecutive conjunctions such as "しかし、しかし" make prose feel redundant
/// and disrupt the flow of a sentence. This rule walks through each sentence,
/// records the first conjunction it encounters, and reports a diagnostic when
/// the same conjunction appears at the beginning of the next sentence.
///
/// Inspired by https://github.com/textlint-ja/textlint-rule-no-doubled-conjunction.
public struct JapaneseConjunctionDuplicationRule: Rule {
  public let id = "ja.conjunction.no-duplicate"
  public let description = "同じ接続詞が連続しないようにしてください。"

  private let conjunctions: [String] = [
    "そして", "しかし", "だが", "だから", "それで", "それでも", "それなら", "それに", "それから",
    "それゆえ", "したがって", "ところが", "けれど", "けれども", "ですが", "また", "さらに", "つまり",
    "一方", "なので", "ですので", "すると", "ゆえに", "よって", "そのため", "その結果", "そのうえ",
    "それにしても", "にもかかわらず",
  ]

  private let sentenceTerminators: Set<Character> = [".", "．", "。", "?", "!", "？", "！"]
  private let allowedLeadingCharacters: Set<Character> = [
    " ", "\t", "\n", "\r", "\r\n", "\u{3000}", "、", "。", "．", ",", ".", "!", "?", "！", "？", "・",
    "-", "—", "―", "〜", "ー", "\u{FF65}", "\u{FF0C}",
    "(", ")", "[", "]", "{", "}", "<", ">", "「", "」", "『", "』", "（", "）", "［", "］",
    "【", "】", "〈", "〉", "《", "》", "：", ";", "；", "“", "”", "'", "\"",
  ]

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let sentenceRanges = self.sentenceRanges(
      in: originalText, skipping: document.codeBlockLineNumbers)
    var lastConjunction: ConjunctionOccurrence?

    for range in sentenceRanges {
      guard let occurrence = firstConjunction(in: originalText, sentenceRange: range) else {
        continue
      }

      if let previous = lastConjunction, previous.conjunction == occurrence.conjunction {
        let (line, column) = originalText.lineAndColumn(of: occurrence.range.lowerBound)
        let diagnostic = Diagnostic(
          file: fileURL,
          line: line,
          column: column,
          ruleID: id,
          message: "同じ接続詞（\(occurrence.conjunction)）が連続して使われています。",
          severity: .warning,
          fixIt: nil
        )
        diagnostics.append(diagnostic)
      }

      lastConjunction = occurrence
    }

    return diagnostics
  }

  /// Splits the text into sentences, leaving out the lines of code blocks.
  ///
  /// A code block also ends the sentence that precedes it.
  private func sentenceRanges(in text: String, skipping codeLines: Set<Int>)
    -> [Range<String.Index>]
  {
    var ranges: [Range<String.Index>] = []
    var start = text.startIndex
    var index = start
    var line = 1
    var inCodeBlock = codeLines.contains(line)

    func endSentence(at end: String.Index) {
      let range = start..<end
      if !range.isEmpty, containsContent(in: text, range: range) {
        ranges.append(range)
      }
    }

    while index < text.endIndex {
      let character = text[index]
      let nextIndex = text.index(after: index)

      if character.isLineTerminator {
        line += 1
        let nextLineIsCode = codeLines.contains(line)
        if inCodeBlock {
          start = nextIndex
        } else if nextLineIsCode {
          endSentence(at: index)
          start = nextIndex
        }
        inCodeBlock = nextLineIsCode
      } else if !inCodeBlock, sentenceTerminators.contains(character) {
        endSentence(at: nextIndex)
        start = nextIndex
      }

      index = nextIndex
    }

    if !inCodeBlock {
      endSentence(at: text.endIndex)
    }

    return ranges
  }

  private func containsContent(in text: String, range: Range<String.Index>) -> Bool {
    let substring = text[range]
    for scalar in substring.unicodeScalars {
      if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
        return true
      }
    }
    return false
  }

  private func firstConjunction(in text: String, sentenceRange: Range<String.Index>)
    -> ConjunctionOccurrence?
  {
    var best: ConjunctionOccurrence?

    for conjunction in conjunctions {
      var searchRange = sentenceRange
      while let foundRange = text.range(of: conjunction, options: [], range: searchRange) {
        if isValidBoundary(in: text, for: foundRange, sentenceRange: sentenceRange) {
          if let currentBest = best {
            // Prefer the earliest match; at the same position prefer the longest one
            // so that "それでも" is not mistaken for "それで".
            if foundRange.lowerBound < currentBest.range.lowerBound
              || (foundRange.lowerBound == currentBest.range.lowerBound
                && foundRange.upperBound > currentBest.range.upperBound)
            {
              best = ConjunctionOccurrence(conjunction: conjunction, range: foundRange)
            }
          } else {
            best = ConjunctionOccurrence(conjunction: conjunction, range: foundRange)
          }
          break
        } else {
          searchRange = foundRange.upperBound..<sentenceRange.upperBound
        }
      }
    }

    return best
  }

  private func isValidBoundary(
    in text: String, for range: Range<String.Index>, sentenceRange: Range<String.Index>
  ) -> Bool {
    if range.lowerBound > sentenceRange.lowerBound {
      let beforeIndex = text.index(before: range.lowerBound)
      let beforeCharacter = text[beforeIndex]
      if !allowedLeadingCharacters.contains(beforeCharacter) {
        return false
      }
    }
    return true
  }

  private struct ConjunctionOccurrence {
    let conjunction: String
    let range: Range<String.Index>
  }
}
