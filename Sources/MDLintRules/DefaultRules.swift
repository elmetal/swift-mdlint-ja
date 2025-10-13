import Foundation
import MDLintCore

public enum DefaultRules {
    public static let all: [Rule] = [
        JapanesePeriodRule(),
        HeadingTerminalPunctuationRule(),
        HeadingLevelSkipRule()
    ]
}
