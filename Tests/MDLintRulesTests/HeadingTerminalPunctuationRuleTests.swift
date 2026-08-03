import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("HeadingTerminalPunctuationRule")
struct HeadingTerminalPunctuationRuleTests {
  @Test func detectsHeadingWithTerminalPunctuation() throws {
    let content = "# 見出し。\n本文"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.message.contains("句読点"))
  }

  @Test func fixRemovesTrailingPunctuationFromHeadings() {
    let content = "# 見出し、\n## 次の見出し．\n通常の行"
    let rule = HeadingTerminalPunctuationRule()

    let fixed = rule.fixing(originalText: content)

    #expect(fixed == "# 見出し\n## 次の見出し\n通常の行")
  }

  @Test func doesNotReportBogusLocationWhenHeadingTextIsNotFoundVerbatim() {
    // A heading containing emphasis has a plainText ("見出し強調。") that does not
    // appear verbatim in the source, so the location cannot be determined and the
    // diagnostic is skipped (previously it was reported at a bogus end-of-document
    // position).
    let content = "# 見出し**強調**。\n本文"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func ignoresHeadingsWithoutTerminalPunctuation() {
    let content = "# 正しい見出し\n## これも正しい"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }
}
