import Foundation
import Markdown
import MDLintCore

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
        "それにしても", "にもかかわらず"
    ]

    private let sentenceTerminators: Set<Character> = [".", "．", "。", "?", "!", "？", "！"]
    private let allowedLeadingCharacters: Set<Character> = [
        " ", "\t", "\n", "\r", "　", "\u{3000}", "、", "。", "．", ",", ".", "!", "?", "！", "？", "・",
        "-", "—", "―", "〜", "ー", "・", "\u{FF65}", "\u{30FB}", "\u{FF0C}", "\u{3001}",
        "(", ")", "[", "]", "{", "}", "<", ">", "「", "」", "『", "』", "（", "）", "［", "］",
        "【", "】", "〈", "〉", "《", "》", "：", ";", "；", "“", "”", "'", "\""
    ]

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let sentenceRanges = self.sentenceRanges(in: originalText)
        var lastConjunction: ConjunctionOccurrence?

        for range in sentenceRanges {
            guard let occurrence = firstConjunction(in: originalText, sentenceRange: range) else { continue }

            if let previous = lastConjunction, previous.conjunction == occurrence.conjunction {
                let (line, column) = lineAndColumn(in: originalText, at: occurrence.range.lowerBound)
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

    private func sentenceRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        var index = start

        while index < text.endIndex {
            let character = text[index]
            if sentenceTerminators.contains(character) {
                let nextIndex = text.index(after: index)
                let range = start..<nextIndex
                if containsContent(in: text, range: range) {
                    ranges.append(range)
                }
                start = nextIndex
            }
            index = text.index(after: index)
        }

        if start < text.endIndex {
            let range = start..<text.endIndex
            if containsContent(in: text, range: range) {
                ranges.append(range)
            }
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

    private func firstConjunction(in text: String, sentenceRange: Range<String.Index>) -> ConjunctionOccurrence? {
        var best: ConjunctionOccurrence?

        for conjunction in conjunctions {
            var searchRange = sentenceRange
            while let foundRange = text.range(of: conjunction, options: [], range: searchRange) {
                if isValidBoundary(in: text, for: foundRange, sentenceRange: sentenceRange) {
                    if let currentBest = best {
                        if foundRange.lowerBound < currentBest.range.lowerBound {
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

    private func isValidBoundary(in text: String, for range: Range<String.Index>, sentenceRange: Range<String.Index>) -> Bool {
        if range.lowerBound > sentenceRange.lowerBound {
            let beforeIndex = text.index(before: range.lowerBound)
            let beforeCharacter = text[beforeIndex]
            if !allowedLeadingCharacters.contains(beforeCharacter) {
                return false
            }
        }
        return true
    }

    private func lineAndColumn(in text: String, at index: String.Index) -> (Int, Int) {
        var line = 1
        var column = 1
        var current = text.startIndex

        while current < index {
            if text[current] == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            current = text.index(after: current)
        }

        return (line, column)
    }

    private struct ConjunctionOccurrence {
        let conjunction: String
        let range: Range<String.Index>
    }
}
