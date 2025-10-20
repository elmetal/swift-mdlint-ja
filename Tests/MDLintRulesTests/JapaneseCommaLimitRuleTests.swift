import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("JapaneseCommaLimitRule")
struct JapaneseCommaLimitRuleTests {
    @Test func reportsWhenCommaLimitExceeded() throws {
        let content = "これは、テストで、例で、確認で、検証です。"
        let document = Document(parsing: content)
        let rule = JapaneseCommaLimitRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.column == 16)
        #expect(diagnostic.message.contains("読点が4つ以上"))
    }

    @Test func ignoresSentencesWithinLimit() {
        let content = "これは、テストで、例で、確認です。"
        let document = Document(parsing: content)
        let rule = JapaneseCommaLimitRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }

    @Test func detectsAcrossMultipleLines() throws {
        let content = "これは、テストで、例で、確認で、\n検証で、別の文です。"
        let document = Document(parsing: content)
        let rule = JapaneseCommaLimitRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.column == 16)
    }
}
