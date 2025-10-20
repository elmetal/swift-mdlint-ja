import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("SentenceLengthLimitRule")
struct SentenceLengthLimitRuleTests {
    @Test func reportsWhenSentenceExceedsLimit() throws {
        let content = String(repeating: "あ", count: 101) + "。"
        let document = Document(parsing: content)
        let rule = SentenceLengthLimitRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.column == 101)
        #expect(diagnostic.message.contains("101文字以上"))
    }

    @Test func ignoresURLsWhenCountingCharacters() {
        let url = "https://example.com/path/to/resource"
        let prefix = String(repeating: "あ", count: 60)
        let suffix = String(repeating: "い", count: 40)
        let content = prefix + url + suffix + "。"
        let document = Document(parsing: content)
        let rule = SentenceLengthLimitRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }

    @Test func supportsVariousURLSchemes() {
        let url = "custom+scheme-1.2://example"
        let prefix = String(repeating: "う", count: 60)
        let suffix = String(repeating: "え", count: 40)
        let content = prefix + url + suffix + "。"
        let document = Document(parsing: content)
        let rule = SentenceLengthLimitRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }

    @Test func detectsAcrossMultipleSentences() throws {
        let firstSentence = "短い文です。"
        let longSentence = String(repeating: "う", count: 101) + "！"
        let content = firstSentence + longSentence
        let document = Document(parsing: content)
        let rule = SentenceLengthLimitRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.column == firstSentence.count + 101)
    }
}
