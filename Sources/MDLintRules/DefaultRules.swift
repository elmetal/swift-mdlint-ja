import Foundation
import MDLintCore

public enum DefaultRules {
    public static let all: [Rule] = Identifier.allCases.map { $0.makeRule() }

    public static func rules(for identifiers: [Identifier]) -> [Rule] {
        identifiers.map { $0.makeRule() }
    }

    public enum Identifier: String, CaseIterable, Codable {
        case japaneseEllipsis = "ja.ellipsis.prefer-double"
        case japanesePeriod = "ja.period.prefer-fullwidth"
        case headingTerminalPunctuation = "ja.heading.no-terminal-punctuation"
        case headingLevelNoSkip = "md.heading.no-skip-level"
        case inlineBacktickClosure = "ja.backtick.unmatched"
        case japaneseEnglishSpacing = "ja.spacing.no-space-between-japanese-and-english"
        case halfwidthKana = "ja.kana.no-halfwidth"

        public func makeRule() -> Rule {
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
            }
        }
    }
}
