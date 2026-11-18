import Foundation
import MDLintCore
import Markdown

/// A rule that ensures consistent use of politeness styles (ですます調 / である調) in Japanese text.
///
/// The rule scans Markdown lines outside of code blocks (a line that ends in an inline
/// code span is not classified by the contents of that span), detects whether each sentence
/// ends in the polite "ですます" style or the plain "である" style, and raises diagnostics when
/// sentences using the minority style are found. The preferred style can be supplied via
/// ``PreferredStyle``; when set to ``PreferredStyle/auto`` the majority style in the document is used.
public struct JapanesePolitenessStyleConsistencyRule: Rule {
  public enum PreferredStyle: String, Sendable {
    case auto
    case desumasu
    case dearu
  }

  private enum DetectedStyle: Sendable {
    case desumasu
    case dearu
  }

  private struct Sentence: Sendable {
    let style: DetectedStyle
    let line: Int
    let column: Int
  }

  public let id = "ja.style.no-mix-dearu-desumasu"
  public let description = "敬体（ですます調）と常体（である調）が混在しないようにしてください。"

  private let preferredStyle: PreferredStyle

  public init(preferredStyle: PreferredStyle = .auto) {
    self.preferredStyle = preferredStyle
  }

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    let sentences = collectSentences(
      from: originalText,
      skipping: document.codeBlockLineNumbers,
      inlineCode: document.inlineCodeRanges(in: originalText))

    guard !sentences.isEmpty else { return [] }

    let politenessCount = sentences.reduce(into: (desumasu: 0, dearu: 0)) {
      partialResult, sentence in
      switch sentence.style {
      case .desumasu:
        partialResult.desumasu += 1
      case .dearu:
        partialResult.dearu += 1
      }
    }

    let targetStyle: DetectedStyle?
    switch preferredStyle {
    case .desumasu:
      targetStyle = .desumasu
    case .dearu:
      targetStyle = .dearu
    case .auto:
      if politenessCount.desumasu > politenessCount.dearu {
        targetStyle = .desumasu
      } else if politenessCount.dearu > politenessCount.desumasu {
        targetStyle = .dearu
      } else {
        targetStyle = nil
      }
    }

    guard let targetStyle else { return [] }

    return sentences.compactMap { sentence in
      guard sentence.style != targetStyle else { return nil }

      let message = message(forSentenceStyle: sentence.style, targetStyle: targetStyle)
      return Diagnostic(
        file: fileURL,
        line: sentence.line,
        column: sentence.column,
        ruleID: id,
        message: message,
        severity: .warning,
        fixIt: nil
      )
    }
  }

  private func message(forSentenceStyle style: DetectedStyle, targetStyle: DetectedStyle) -> String
  {
    switch (style, targetStyle) {
    case (.desumasu, .dearu):
      return "敬体（ですます調）と常体（である調）が混在しています。この文は敬体なので常体に揃えましょう。"
    case (.dearu, .desumasu):
      return "敬体（ですます調）と常体（である調）が混在しています。この文は常体なので敬体に揃えましょう。"
    case (.desumasu, .desumasu), (.dearu, .dearu):
      return ""
    }
  }

  private func collectSentences(
    from text: String, skipping codeLines: Set<Int>, inlineCode: InlineCodeRanges
  ) -> [Sentence] {
    var sentences: [Sentence] = []

    for (index, line) in text.sourceLines.enumerated() {
      let lineNumber = index + 1
      if codeLines.contains(lineNumber) { continue }

      guard let detection = detectStyle(in: line, inlineCode: inlineCode) else { continue }

      sentences.append(Sentence(style: detection.style, line: lineNumber, column: detection.column))
    }

    return sentences
  }

  private func detectStyle(in line: Substring, inlineCode: InlineCodeRanges)
    -> (style: DetectedStyle, column: Int)?
  {
    // Ignore trailing whitespace, then trailing punctuation and closing marks.
    var end = line.endIndexIgnoringTrailingSpacesAndTabs
    while end > line.startIndex, Self.trailingCharacters.contains(line[line.index(before: end)]) {
      end = line.index(before: end)
    }
    let normalized = line[..<end]

    guard !normalized.isEmpty else { return nil }

    let style: DetectedStyle
    let suffix: String
    if let match = matchSuffix(in: normalized, using: Self.desumasuSuffixes) {
      (style, suffix) = (.desumasu, match)
    } else if let match = matchSuffix(in: normalized, using: Self.dearuSuffixes) {
      (style, suffix) = (.dearu, match)
    } else {
      return nil
    }

    let suffixStart = normalized.index(end, offsetBy: -suffix.count)
    // A line that ends in inline code says nothing about the style of the prose.
    guard !inlineCode.contains(suffixStart) else { return nil }
    return (style, line.distance(from: line.startIndex, to: suffixStart) + 1)
  }

  private func matchSuffix(in text: Substring, using suffixes: [String]) -> String? {
    for suffix in suffixes {
      if text.hasSuffix(suffix) {
        return suffix
      }
    }
    return nil
  }

  private static let trailingCharacters: Set<Character> = [
    "。", "．", ".", "!", "！", "?", "？", "〜", "～", "♪", "…",
    "\"", "'", "」", "』", "〕", "］", "）", "〉", "》", "】", ">", "、",
    "*", "_", "`",
  ]

  private static let desumasuSuffixes: [String] = {
    let suffixes = [
      "です", "ます", "でした", "ました", "ません", "ませんでした", "でしょう", "ましょう",
      "ですよ", "ですね", "ますね", "でしたね", "でしょうね", "ですか", "ますか", "でしたか", "ましたか",
      "でしょうか", "ましょうか", "ませんか",
    ]
    return suffixes.sorted { $0.count > $1.count }
  }()

  private static let dearuSuffixes: [String] = {
    let suffixes = [
      "だ", "である", "だった", "であった", "ではない", "ではなかった", "だろう", "であろう",
      "だよ", "だね", "だな", "であるか", "だろうか", "であろうか",
    ]
    return suffixes.sorted { $0.count > $1.count }
  }()
}
