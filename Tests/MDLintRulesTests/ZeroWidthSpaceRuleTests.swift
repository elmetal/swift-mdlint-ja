import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("ZeroWidthSpaceRule")
struct ZeroWidthSpaceRuleTests {
    @Test func reportsZeroWidthSpaces() throws {
        let content = "行頭\u{200B}に含まれています"
        let document = Document(parsing: content)
        let rule = ZeroWidthSpaceRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.column == 3)
    }

    @Test func fixRemovesZeroWidthSpaces() {
        let content = "前\u{200B}後\n別の行"
        let rule = ZeroWidthSpaceRule()

        let fixed = rule.fixing(originalText: content)

        #expect(fixed == "前後\n別の行")
    }

    @Test func passesWhenNoZeroWidthSpacesArePresent() {
        let content = "ゼロ幅スペースなし"
        let document = Document(parsing: content)
        let rule = ZeroWidthSpaceRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}
