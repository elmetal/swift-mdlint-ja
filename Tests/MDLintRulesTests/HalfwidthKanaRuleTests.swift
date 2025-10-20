import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("HalfwidthKanaRule")
struct HalfwidthKanaRuleTests {
    @Test func reportsHalfwidthKanaCharacters() throws {
        let content = "これはﾃｽﾄです"
        let document = Document(parsing: content)
        let rule = HalfwidthKanaRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 3)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.column == 4)
    }

    @Test func passesWhenOnlyFullwidthKanaIsPresent() {
        let content = "これはテストです"
        let document = Document(parsing: content)
        let rule = HalfwidthKanaRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}
