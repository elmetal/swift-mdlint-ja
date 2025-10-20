import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("JapaneseParticleDuplicationRule")
struct JapaneseParticleDuplicationRuleTests {
    @Test func reportsDuplicatedParticles() throws {
        let content = "これはサンプルにになります。"
        let document = Document(parsing: content)
        let rule = JapaneseParticleDuplicationRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
    }

    @Test func ignoresSentencesWithoutDuplicatedParticles() {
        let content = "これはサンプルになります。"
        let document = Document(parsing: content)
        let rule = JapaneseParticleDuplicationRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}
