import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("InlineBacktickClosureRule")
struct InlineBacktickClosureRuleTests {
    @Test func reportsLineWithUnclosedBacktick() throws {
        let content = "これは `テストです"
        let document = Document(parsing: content)
        let rule = InlineBacktickClosureRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
    }

    @Test func passesWhenBackticksAreClosed() {
        let content =
"""
これは `テスト` です
```
コードブロック内の ` は無視
```
"""
        let document = Document(parsing: content)
        let rule = InlineBacktickClosureRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}
