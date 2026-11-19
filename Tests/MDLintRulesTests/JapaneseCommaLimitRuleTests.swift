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
}
