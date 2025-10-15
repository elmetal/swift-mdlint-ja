import Foundation
import MDLintCore

public enum DefaultRules {
    public static let all: [Rule] = [
        JapaneseEllipsisRule(),
        JapanesePeriodRule(),
        HeadingTerminalPunctuationRule(),
        HeadingLevelSkipRule()
    ]
}
