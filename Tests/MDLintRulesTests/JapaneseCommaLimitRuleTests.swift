import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("JapaneseCommaLimitRule")
struct JapaneseCommaLimitRuleTests {
  @Test func reportsWhenCommaLimitExceeded() throws {
    let content = "これは、テストで、例で、確認で、検証です。"
    let document = Document(parsing: content)
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 16)
    #expect(diagnostic.message.contains("読点が4つ以上"))
  }

  @Test func ignoresSentencesWithinLimit() {
    let content = "これは、テストで、例で、確認です。"
    let document = Document(parsing: content)
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func detectsAcrossMultipleLines() throws {
    let content = "これは、テストで、例で、確認で、\n検証で、別の文です。"
    let document = Document(parsing: content)
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 16)
  }

  @Test func reportsCorrectLineWithWindowsLineEndings() throws {
    let content = "# 見出し\r\n\r\nこれは、テストで、例で、確認で、検証です。\r\n"
    let document = Document(parsing: content)
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 3)
    #expect(diagnostic.column == 16)
  }

  @Test func doesNotCountCommasAcrossParagraphs() {
    let content = "項目A、項目B\n\n項目C、項目D\n\n項目E、項目F\n\n項目G、項目H"
    let document = Document(parsing: content)
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func doesNotCountCommasInsideOrAcrossCodeBlocks() {
    // The commas inside the code block are ignored, and the block separates the
    // text before it from the text after it even without blank lines.
    let content = "これは、テストで、\n```\n一、二、三、四、五\n```\n例で、確認です"
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func doesNotCountCommasInsideInlineCode() {
    let content = "これは、`一、二、三、四` と、書きます。"
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func terminatorInsideInlineCodeDoesNotEndTheSentence() throws {
    // Without the code span being skipped, "!" would split this into two sentences
    // with two commas each.
    let content = "一、二、`x != y` 三、四、五。"
    let rule = JapaneseCommaLimitRule()

    let diagnostics = rule.diagnostics(for: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.column == 17)
  }

  @Test func usesTheGivenLimit() throws {
    let content = "一、二、三、四、五、六。"

    #expect(JapaneseCommaLimitRule(maxCommaCount: 5).diagnostics(for: content).isEmpty)

    let rule = JapaneseCommaLimitRule(maxCommaCount: 1)
    let diagnostic = try #require(rule.diagnostics(for: content).first)
    // The second comma is the first one over the limit.
    #expect(diagnostic.column == 4)
    #expect(diagnostic.ruleID == "ja.comma.max-count")
    #expect(diagnostic.message.contains("2つ以上"))
    #expect(rule.description == "一文に含める読点は1つまでにしてください。")
  }

  @Test func keepsTheDefaultWordingForTheDefaultLimit() throws {
    let rule = JapaneseCommaLimitRule()
    let diagnostic = try #require(rule.diagnostics(for: "一、二、三、四、五。").first)

    #expect(rule.description == "一文に含める読点は3つまでにしてください。")
    #expect(diagnostic.message.hasPrefix("一文に読点が4つ以上あります（読点の数: 4）。"))
  }

  @Test func countsLargeLimitsWithAnotherCounter() throws {
    let rule = JapaneseCommaLimitRule(maxCommaCount: 10)
    let content = String(repeating: "あ、", count: 11) + "終わり。"
    let diagnostic = try #require(rule.diagnostics(for: content).first)

    #expect(rule.description == "一文に含める読点は10個までにしてください。")
    #expect(diagnostic.message.contains("11個以上"))
  }
}
