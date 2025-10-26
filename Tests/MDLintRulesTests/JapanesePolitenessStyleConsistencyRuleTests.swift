import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("JapanesePolitenessStyleConsistencyRule")
struct JapanesePolitenessStyleConsistencyRuleTests {
    @Test func reportsDearuWhenDesumasuIsMajority() throws {
        let content = "これはテストです。\nこの文も丁寧語です。\nこれは事実である。"
        let document = Document(parsing: content)
        let rule = JapanesePolitenessStyleConsistencyRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.line == 3)
        #expect(diagnostic.ruleID == rule.id)
    }

    @Test func reportsDesumasuWhenDearuPreferred() throws {
        let content = "これは事実である。\n別の文だ。\nしかし説明します。"
        let document = Document(parsing: content)
        let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .dearu)

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.line == 3)
        #expect(diagnostic.ruleID == rule.id)
    }

    @Test func returnsEmptyWhenStylesAreBalancedAndAuto() {
        let content = "これはテストです。\nこれは報告である。"
        let document = Document(parsing: content)
        let rule = JapanesePolitenessStyleConsistencyRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }

    @Test func ignoresLinesInsideCodeBlocks() {
        let content = "これはテストです。\n```\nこれは報告である。\n```"
        let document = Document(parsing: content)
        let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .desumasu)

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}
