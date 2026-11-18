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

  @Test func reportsColumnOfThePeriodIgnoringTrailingSpaces() throws {
    let content = "これはテスト.  "
    let document = Document(parsing: content)
    let rule = JapanesePeriodRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.column == 7)
  }

  @Test func handlesWindowsLineEndings() {
    let content = "一行目.\r\n二行目。\r\n"
    let document = Document(parsing: content)
    let rule = JapanesePeriodRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [1])
    #expect(rule.fixing(originalText: content) == "一行目。\r\n二行目。\r\n")
  }

  @Test func leavesCodeBlocksAlone() {
    let content = "本文です.\n\n```bash\n# Install the tool.\n```\n\n    indented code.\n"
    let document = Document(parsing: content)
    let rule = JapanesePeriodRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [1])
    #expect(
      rule.fixing(originalText: content)
        == "本文です。\n\n```bash\n# Install the tool.\n```\n\n    indented code.\n")
  }
}
