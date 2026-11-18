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
    let rule = JapanesePeriodRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.map(\.line) == [1])
    #expect(
      rule.fixed(content)
        == "本文です。\n\n```bash\n# Install the tool.\n```\n\n    indented code.\n")
  }

  @Test func leavesPeriodInsideInlineCodeAlone() {
    // The first line ends inside a code span that continues on the next line.
    let content = "パスは `a.\nb` です.\n"
    let rule = JapanesePeriodRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.map(\.line) == [2])
    #expect(rule.fixed(content) == "パスは `a.\nb` です。\n")
  }

  @Test(arguments: [
    "See the README for details.",
    "1.",
    "１．",
    "- Install the tool.",
    "Run `mdlint-ja --fix`.",
    "日本語の文です。This one is English.",
    "これは日本語です! Not this one.",
    "東京は Tokyo. This is English.",
    "etc.",
  ])
  func leavesLinesThatDoNotEndAJapaneseSentenceAlone(content: String) {
    let document = Document(parsing: content)
    let rule = JapanesePeriodRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
    #expect(rule.fixing(originalText: content) == content)
  }

  @Test(arguments: [
    ("これは Swift.", "これは Swift。"),
    ("1. これは項目です.", "1. これは項目です。"),
    ("Swift 6.0 に対応しました.", "Swift 6.0 に対応しました。"),
    ("詳細は example.com を参照.", "詳細は example.com を参照。"),
    ("English first. 次は日本語です.", "English first. 次は日本語です。"),
    ("カタカナ.", "カタカナ。"),
    ("「引用」.", "「引用」。"),
  ])
  func fixesPeriodsThatEndAJapaneseSentence(content: String, expected: String) {
    let document = Document(parsing: content)
    let rule = JapanesePeriodRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    #expect(rule.fixing(originalText: content) == expected)
  }

  @Test(arguments: ["そうですね...", "そうですね．．．", "つづく.."])
  func leavesEllipsesMadeOfPeriodsAlone(content: String) {
    let document = Document(parsing: content)
    let rule = JapanesePeriodRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
    #expect(rule.fixing(originalText: content) == content)
  }
}
