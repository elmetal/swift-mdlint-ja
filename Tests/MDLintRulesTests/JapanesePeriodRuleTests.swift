import Foundation
import Markdown
import Testing
@testable import MDLintRules

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
