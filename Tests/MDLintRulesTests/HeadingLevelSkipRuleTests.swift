import Foundation
import Markdown
import Testing
@testable import MDLintRules

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
