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
    #expect(diagnostic.column == 6)
    #expect(diagnostic.message.contains("句読点「。」"))
  }

  @Test func fixRemovesTrailingPunctuationFromHeadings() {
    let content = "# 見出し、\n## 次の見出し．\n通常の行"
    let rule = HeadingTerminalPunctuationRule()

    let fixed = rule.fixed(content)

    #expect(fixed == "# 見出し\n## 次の見出し\n通常の行")
  }

  @Test func reportsExactLocationWhenHeadingContainsInlineMarkup() throws {
    // The location comes from the parsed heading, so inline markup inside the
    // heading does not prevent the punctuation from being found.
    let content = "# 見出し**強調**。\n本文"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 12)
    #expect(rule.fixed(content) == "# 見出し**強調**\n本文")
  }

  @Test func reportsEachHeadingAtItsOwnLocation() {
    // The same text appears in a paragraph and in two headings.
    let content = "概要。\n\n## 概要。\n\n本文\n\n## 概要。"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [3, 7])
    #expect(diagnostics.map(\.column) == [6, 6])
    #expect(rule.fixed(content) == "概要。\n\n## 概要\n\n本文\n\n## 概要")
  }

  @Test func leavesHashLinesInsideCodeBlocksAlone() {
    let content = "```bash\n# Install the tool.\n```\n"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
    #expect(rule.fixed(content) == content)
  }

  @Test func handlesClosedAndSetextHeadingsAndWindowsLineEndings() {
    let content = "## 閉じ。 ##\r\n\r\nセクション、\r\n---\r\n"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [1, 3])
    #expect(diagnostics.map(\.column) == [6, 6])
    #expect(rule.fixed(content) == "## 閉じ ##\r\n\r\nセクション\r\n---\r\n")
  }

  @Test func ignoresHeadingsWithoutTerminalPunctuation() {
    let content = "# 正しい見出し\n## これも正しい"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test(arguments: [
    ("## `code` の使い方。\n", 15, "## `code` の使い方\n"),
    ("## 設定 `値が日本語` です.\n", 17, "## 設定 `値が日本語` です\n"),
    ("# 見出し `code`.\n", 13, "# 見出し `code`\n"),
    ("# <b>強調</b> です、\n", 15, "# <b>強調</b> です\n"),
    ("- ### 項目の `x` 見出し。\n", 18, "- ### 項目の `x` 見出し\n"),
    ("`a` と `b`。\n===\n", 10, "`a` と `b`\n===\n"),
  ])
  func findsPunctuationAfterHiddenText(content: String, column: Int, expected: String) throws {
    // Code and HTML reach the rule as placeholders, which take a different
    // number of bytes than the characters they stand for.
    let rule = HeadingTerminalPunctuationRule()

    let diagnostic = try #require(rule.diagnostics(for: content).first)

    #expect(diagnostic.column == column)
    #expect(rule.fixed(content) == expected)
  }

  @Test func handlesHeadingsWithAndWithoutHiddenTextInOneFile() {
    let content = "# 一つ目。\n\n## `code` の二つ目。\n\n```\n# コード。\n```\n\n三つ目。\n---\n"
    let rule = HeadingTerminalPunctuationRule()

    #expect(rule.diagnostics(for: content).map(\.line) == [1, 3, 9])
    #expect(
      rule.fixed(content) == "# 一つ目\n\n## `code` の二つ目\n\n```\n# コード。\n```\n\n三つ目\n---\n")
  }

  @Test func doesNotReportAHeadingThatEndsInCode() {
    let rule = HeadingTerminalPunctuationRule()

    #expect(rule.diagnostics(for: "## 末尾は `code。`\n").isEmpty)
    #expect(rule.diagnostics(for: "## `a。` と <b>b。</b>\n").isEmpty)
  }
}
