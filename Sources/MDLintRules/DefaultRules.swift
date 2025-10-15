import Foundation
import MDLintCore

public enum DefaultRules {
    public static let all: [Rule] = [
        InlineBacktickClosureRule(),
        JapaneseEllipsisRule(),
        JapanesePeriodRule(),
        HeadingTerminalPunctuationRule(),
        HeadingLevelSkipRule()
    ]
}
