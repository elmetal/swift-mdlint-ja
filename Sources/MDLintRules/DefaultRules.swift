import Foundation
import MDLintCore

public enum DefaultRules {
  /// The settings of the rules that can be adjusted.
  public struct Options {
    /// The style that the politeness-style consistency rule enforces.
    public var politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle
    /// The number of commas a sentence may contain.
    public var maxCommaCount: Int
    /// The number of characters a sentence may contain.
    public var maxSentenceLength: Int

    public init(
      politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle = .auto,
      maxCommaCount: Int = JapaneseCommaLimitRule.defaultMaxCommaCount,
      maxSentenceLength: Int = SentenceLengthLimitRule.defaultMaxLength
    ) {
      self.politenessStyle = politenessStyle
      self.maxCommaCount = maxCommaCount
      self.maxSentenceLength = maxSentenceLength
    }
  }

  public static func all(options: Options = Options()) -> [Rule] {
    Identifier.allCases.map { $0.makeRule(options: options) }
  }

  public static func rules(for identifiers: [Identifier], options: Options = Options()) -> [Rule] {
    identifiers.map { $0.makeRule(options: options) }
  }

  public enum Identifier: String, CaseIterable, Codable, Sendable {
    case japaneseEllipsis = "ja.ellipsis.prefer-double"
    case japanesePeriod = "ja.period.prefer-fullwidth"
    case headingTerminalPunctuation = "ja.heading.no-terminal-punctuation"
    case headingLevelNoSkip = "md.heading.no-skip-level"
    case inlineBacktickClosure = "ja.backtick.unmatched"
    case japaneseEnglishSpacing = "ja.spacing.no-space-between-japanese-and-english"
    case halfwidthKana = "ja.kana.no-halfwidth"
    case japaneseParticleDuplication = "ja.particle.no-duplicate"
    case japaneseConjunctionDuplication = "ja.conjunction.no-duplicate"
    case zeroWidthSpace = "md.whitespace.no-zero-width-space"
    case controlCharacter = "md.characters.no-control"
    case japaneseCommaLimit = "ja.comma.max-count"
    case sentenceLengthLimit = "ja.sentence.max-length"
    case japanesePolitenessStyleConsistency = "ja.style.no-mix-dearu-desumasu"

    /// The names that rules had before their limits became adjustable.
    ///
    /// Configuration files written for earlier versions use them.
    public static let formerNames: [String: Identifier] = [
      "ja.comma.max-three": .japaneseCommaLimit,
      "ja.sentence.max-one-hundred-characters": .sentenceLengthLimit,
    ]

    /// Creates an identifier from its name or from one of its former names.
    public init?(name: String) {
      guard let identifier = Identifier(rawValue: name) ?? Self.formerNames[name] else {
        return nil
      }
      self = identifier
    }

    public func makeRule(options: Options) -> Rule {
      switch self {
      case .japaneseEllipsis:
        return JapaneseEllipsisRule()
      case .japanesePeriod:
        return JapanesePeriodRule()
      case .headingTerminalPunctuation:
        return HeadingTerminalPunctuationRule()
      case .headingLevelNoSkip:
        return HeadingLevelSkipRule()
      case .inlineBacktickClosure:
        return InlineBacktickClosureRule()
      case .japaneseEnglishSpacing:
        return JapaneseEnglishSpacingRule()
      case .halfwidthKana:
        return HalfwidthKanaRule()
      case .japaneseParticleDuplication:
        return JapaneseParticleDuplicationRule()
      case .japaneseConjunctionDuplication:
        return JapaneseConjunctionDuplicationRule()
      case .zeroWidthSpace:
        return ZeroWidthSpaceRule()
      case .controlCharacter:
        return ControlCharacterRule()
      case .japaneseCommaLimit:
        return JapaneseCommaLimitRule(maxCommaCount: options.maxCommaCount)
      case .sentenceLengthLimit:
        return SentenceLengthLimitRule(maxLength: options.maxSentenceLength)
      case .japanesePolitenessStyleConsistency:
        return JapanesePolitenessStyleConsistencyRule(preferredStyle: options.politenessStyle)
      }
    }
  }
}
