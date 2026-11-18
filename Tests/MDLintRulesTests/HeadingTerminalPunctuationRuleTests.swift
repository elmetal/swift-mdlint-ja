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

    let fixed = rule.fixing(originalText: content)

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
    #expect(rule.fixing(originalText: content) == "# 見出し**強調**\n本文")
  }

  @Test func reportsEachHeadingAtItsOwnLocation() {
    // The same text appears in a paragraph and in two headings.
    let content = "概要。\n\n## 概要。\n\n本文\n\n## 概要。"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [3, 7])
    #expect(diagnostics.map(\.column) == [6, 6])
    #expect(rule.fixing(originalText: content) == "概要。\n\n## 概要\n\n本文\n\n## 概要")
  }

  @Test func leavesHashLinesInsideCodeBlocksAlone() {
    let content = "```bash\n# Install the tool.\n```\n"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
    #expect(rule.fixing(originalText: content) == content)
  }

  @Test func handlesClosedAndSetextHeadingsAndWindowsLineEndings() {
    let content = "## 閉じ。 ##\r\n\r\nセクション、\r\n---\r\n"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [1, 3])
    #expect(diagnostics.map(\.column) == [6, 6])
    #expect(rule.fixing(originalText: content) == "## 閉じ ##\r\n\r\nセクション\r\n---\r\n")
  }

  @Test func ignoresHeadingsWithoutTerminalPunctuation() {
    let content = "# 正しい見出し\n## これも正しい"
    let document = Document(parsing: content)
    let rule = HeadingTerminalPunctuationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }
}
