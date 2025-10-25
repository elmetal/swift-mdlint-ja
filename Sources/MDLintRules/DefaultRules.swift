import Foundation
import MDLintCore

public enum DefaultRules {
    public struct Options {
        public var politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle

        public init(politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle = .auto) {
            self.politenessStyle = politenessStyle
        }
    }

    public static func all(options: Options = Options()) -> [Rule] {
        Identifier.allCases.map { $0.makeRule(options: options) }
    }

    public static func rules(for identifiers: [Identifier], options: Options = Options()) -> [Rule] {
        identifiers.map { $0.makeRule(options: options) }
    }

    public enum Identifier: String, CaseIterable, Codable {
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
        case japaneseCommaLimit = "ja.comma.max-three"
        case sentenceLengthLimit = "ja.sentence.max-one-hundred-characters"
        case japanesePolitenessStyleConsistency = "ja.style.no-mix-dearu-desumasu"

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
                return JapaneseCommaLimitRule()
            case .sentenceLengthLimit:
                return SentenceLengthLimitRule()
            case .japanesePolitenessStyleConsistency:
                return JapanesePolitenessStyleConsistencyRule(preferredStyle: options.politenessStyle)
            }
        }
    }
}
