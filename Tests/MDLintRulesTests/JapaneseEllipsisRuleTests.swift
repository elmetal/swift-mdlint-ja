import Foundation
import Markdown
import Testing
@testable import MDLintRules

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
