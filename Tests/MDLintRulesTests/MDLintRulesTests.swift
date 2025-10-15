import Foundation
import Markdown
import Testing
@testable import MDLintRules

private let sampleFileURL = URL(fileURLWithPath: "/tmp/rules.md")

@Suite("JapanesePeriodRule")
struct JapanesePeriodRuleTests {
    @Test func reportsLinesEndingWithHalfwidthPeriod() throws {
        let content = "これはテスト.\n別の行"
        let document = Document(parsing: content)
        let rule = JapanesePeriodRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
    }

    @Test func fixReplacesHalfwidthAndFullwidthPeriods() {
        let content = "一行目．  \n二行目.\n末尾はそのまま"
        let rule = JapanesePeriodRule()

        let fixed = rule.fixing(originalText: content)

        #expect(fixed == "一行目。  \n二行目。\n末尾はそのまま")
    }

    @Test func passesWhenAllSentencesEndWithJapanesePeriod() {
        let content = "これはテスト。\nこれもテスト。"
        let document = Document(parsing: content)
        let rule = JapanesePeriodRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}

@Suite("HeadingTerminalPunctuationRule")
struct HeadingTerminalPunctuationRuleTests {
    @Test func detectsHeadingWithTerminalPunctuation() throws {
        let content = "# 見出し。\n本文"
        let document = Document(parsing: content)
        let rule = HeadingTerminalPunctuationRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.message.contains("句読点"))
    }

    @Test func fixRemovesTrailingPunctuationFromHeadings() {
        let content = "# 見出し、\n## 次の見出し．\n通常の行"
        let rule = HeadingTerminalPunctuationRule()

        let fixed = rule.fixing(originalText: content)

        #expect(fixed == "# 見出し\n## 次の見出し\n通常の行")
    }

    @Test func ignoresHeadingsWithoutTerminalPunctuation() {
        let content = "# 正しい見出し\n## これも正しい"
        let document = Document(parsing: content)
        let rule = HeadingTerminalPunctuationRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}

@Suite("HeadingLevelSkipRule")
struct HeadingLevelSkipRuleTests {
    @Test func reportsSkippedHeadingLevels() throws {
        let content = "# タイトル\n## セクション\n#### 飛び級"
        let document = Document(parsing: content)
        let rule = HeadingLevelSkipRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 3)
    }

    @Test func allowsSequentialHeadingLevels() {
        let content = "# タイトル\n## セクション\n### サブセクション"
        let document = Document(parsing: content)
        let rule = HeadingLevelSkipRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}

@Suite("JapaneseEllipsisRule")
struct JapaneseEllipsisRuleTests {
    @Test func reportsOddCountEllipsis() throws {
        let content = "これはテスト…\nこれは問題なし……"
        let document = Document(parsing: content)
        let rule = JapaneseEllipsisRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
    }

    @Test func fixNormalizesOddEllipsisCounts() {
        let content = "単独…\n奇数連続………\n偶数は……そのまま"
        let rule = JapaneseEllipsisRule()

        let fixed = rule.fixing(originalText: content)

        #expect(fixed == "単独……\n奇数連続…………\n偶数は……そのまま")
    }

    @Test func passesWhenEllipsisAreEven() {
        let content = "これは問題なし……\n連続でも…………"
        let document = Document(parsing: content)
        let rule = JapaneseEllipsisRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}
