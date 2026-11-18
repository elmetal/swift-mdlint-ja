import Foundation
import MDLintCore
import Markdown

/// A rule that standardizes sentence-ending punctuation to "。".
///
/// Japanese prose typically concludes sentences with the full-width "。"
/// character. The rule reviews each line of Markdown text and raises a
/// diagnostic—along with an autofix suggestion—whenever a Japanese sentence
/// ends the line with "." or "．". The linter hides code and raw HTML before
/// the rule runs, so a period inside either is left alone.
///
/// Only a period that closes a sentence written in Japanese is reported. The
/// sentence is the part of the line that follows the previous terminator, and
/// it counts as Japanese when it contains kanji or kana. The following line
/// endings are therefore left alone:
///
/// - English sentences, as in "See the README.", including one that follows a
///   Japanese sentence on the same line.
/// - List markers and other periods without Japanese text, such as "1.".
/// - Runs of periods used as an ellipsis, such as "...".
public struct JapanesePeriodRule: Rule, AutoFixable {
  public let id = "ja.period.prefer-fullwidth"
  public let description = "文末の終止符は「。」に統一してください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var out: [Diagnostic] = []

    // 単純化: 行単位で見る。日本語の文を閉じる末尾の "." または "．" を検出
    for (i, line) in originalText.sourceLines.enumerated() {
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
    originalText.mappingSourceLines { line in
      guard let index = Self.terminalPeriodIndex(in: line) else { return String(line) }
      // 行末の "."/ "．" を "。" に置換し、後続の空白は保持する
      return line[..<index] + "。" + line[line.index(after: index)...]
    }
  }

  /// Returns the index of a "." or "．" that ends a Japanese sentence at the end of the line,
  /// ignoring trailing whitespace.
  private static func terminalPeriodIndex(in line: Substring) -> String.Index? {
    guard let index = line.lastIndex(where: { !$0.isWhitespace }), isPeriod(line[index]) else {
      return nil
    }
    let preceding = line[..<index]
    // A run of periods is an ellipsis, not the end of a sentence.
    if let previous = preceding.last, isPeriod(previous) { return nil }
    return sentence(endingAt: index, in: line).contains(japaneseCharacterRegex) ? index : nil
  }

  /// Returns the part of `line` that the period at `end` closes: everything after the previous
  /// sentence terminator.
  ///
  /// An ASCII period ends a sentence only when whitespace follows it, so that the periods in
  /// "v1.2" or "example.com" do not split the sentence.
  private static func sentence(endingAt end: String.Index, in line: Substring) -> Substring {
    var start = end
    while start > line.startIndex {
      let previous = line.index(before: start)
      let character = line[previous]
      if sentenceTerminators.contains(character) || (character == "." && line[start].isWhitespace) {
        break
      }
      start = previous
    }
    return line[start..<end]
  }

  private static func isPeriod(_ character: Character) -> Bool {
    character == "." || character == "．"
  }

  private static let sentenceTerminators: Set<Character> = ["。", "．", "！", "？", "!", "?"]

  // Regex is not Sendable, so this is computed rather than a stored static.
  private static var japaneseCharacterRegex: Regex<Substring> {
    /[\p{Han}\p{Hiragana}\p{Katakana}々〆ヵヶ]/
  }
}
