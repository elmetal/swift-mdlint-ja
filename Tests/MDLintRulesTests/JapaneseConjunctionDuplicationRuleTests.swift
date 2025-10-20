import Foundation
import Markdown
import Testing
@testable import MDLintRules

@Suite("JapaneseConjunctionDuplicationRule")
struct JapaneseConjunctionDuplicationRuleTests {
    @Test func reportsDuplicatedConjunctionsInSingleParagraph() throws {
        let content = "朝起きた。そして昼は仕事をした。そして夜に寝た"
        let document = Document(parsing: content)
        let rule = JapaneseConjunctionDuplicationRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.line == 1)
        #expect(diagnostic.column == 17)
        #expect(diagnostic.message.contains("同じ接続詞（そして）が連続して使われています。"))
    }

    @Test func reportsDuplicatesAcrossParagraphs() throws {
        let content = "1行目。\n\nそして朝起きた。昼は仕事をした。そして夜に寝た。\n\n5行目。"
        let document = Document(parsing: content)
        let rule = JapaneseConjunctionDuplicationRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.line == 3)
        #expect(diagnostic.column == 17)
    }

    @Test func allowsDifferentConjunctions() {
        let content = "かな漢字変換により漢字が多用される傾向がある。しかし昼は仕事をした。だが夜に寝た。"
        let document = Document(parsing: content)
        let rule = JapaneseConjunctionDuplicationRule()

        let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

        #expect(diagnostics.isEmpty)
    }
}
