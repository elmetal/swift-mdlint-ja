import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("SentenceLengthLimitRule")
struct SentenceLengthLimitRuleTests {
  @Test func reportsWhenSentenceExceedsLimit() throws {
    let content = String(repeating: "あ", count: 101) + "。"
    let document = Document(parsing: content)
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 101)
    #expect(diagnostic.message.contains("101文字以上"))
  }

  @Test func ignoresURLsWhenCountingCharacters() {
    let url = "https://example.com/path/to/resource"
    let prefix = String(repeating: "あ", count: 60)
    let suffix = String(repeating: "い", count: 40)
    let content = prefix + url + suffix + "。"
    let document = Document(parsing: content)
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func supportsVariousURLSchemes() {
    let url = "custom+scheme-1.2://example"
    let prefix = String(repeating: "う", count: 60)
    let suffix = String(repeating: "え", count: 40)
    let content = prefix + url + suffix + "。"
    let document = Document(parsing: content)
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func detectsAcrossMultipleSentences() throws {
    let firstSentence = "短い文です。"
    let longSentence = String(repeating: "う", count: 101) + "！"
    let content = firstSentence + longSentence
    let document = Document(parsing: content)
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == firstSentence.count + 101)
  }

  @Test func doesNotCountCharactersAcrossParagraphs() {
    let paragraph = String(repeating: "あ", count: 60)
    let content = "# 見出し\n\n" + paragraph + "\n\n" + paragraph + "\n"
    let document = Document(parsing: content)
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func reportsCorrectLineWithWindowsLineEndings() throws {
    let content = "短い文です。\r\n\r\n" + String(repeating: "あ", count: 101) + "。\r\n"
    let document = Document(parsing: content)
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 3)
    #expect(diagnostic.column == 101)
  }

  @Test func doesNotCountCharactersInsideOrAcrossCodeBlocks() {
    let prose = String(repeating: "あ", count: 60)
    let code = String(repeating: "x", count: 200)
    let content = prose + "\n```\n" + code + "\n```\n" + prose
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func doesNotCountMarkupAroundACodeBlock() {
    // Each sentence is exactly 100 characters long, line break included. The
    // indentation in front of the fence and the line break after the closing
    // fence belong to the code block, not to the sentences around it.
    let content =
      "- " + String(repeating: "あ", count: 97) + "\n  ```\n  code\n  ```\n  "
      + String(repeating: "い", count: 97) + "\n"
    let rule = SentenceLengthLimitRule()

    #expect(rule.diagnostics(for: content).isEmpty)
  }

  @Test func reportsCorrectLocationAfterCodeBlock() throws {
    let content = "```\ncode\n```\n" + String(repeating: "あ", count: 101) + "。"
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.diagnostics(for: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 4)
    #expect(diagnostic.column == 101)
  }

  @Test func doesNotCountInlineCode() {
    let code = "`" + String(repeating: "x", count: 100) + "`"
    let content =
      String(repeating: "あ", count: 60) + code + String(repeating: "い", count: 30) + "。"
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func terminatorInsideInlineCodeDoesNotEndTheSentence() throws {
    // Without the code span being skipped, "?" would split this into two short sentences.
    let content =
      String(repeating: "あ", count: 60) + "`a?b`" + String(repeating: "い", count: 50) + "。"
    let rule = SentenceLengthLimitRule()

    let diagnostics = rule.diagnostics(for: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    // 60 counted characters, 5 skipped for the code span, then the 41st "い".
    #expect(diagnostic.column == 106)
    #expect(diagnostic.message.contains("現在の文字数: 111"))
  }

  @Test func usesTheGivenLimit() throws {
    let content = String(repeating: "あ", count: 120) + "。"

    #expect(SentenceLengthLimitRule(maxLength: 121).diagnostics(for: content).isEmpty)

    let rule = SentenceLengthLimitRule(maxLength: 10)
    let diagnostic = try #require(rule.diagnostics(for: content).first)
    #expect(diagnostic.column == 11)
    #expect(diagnostic.ruleID == "ja.sentence.max-length")
    #expect(diagnostic.message.contains("11文字以上"))
    #expect(diagnostic.message.contains("10文字以内"))
    #expect(rule.description == "URL とコードを除いて一文は10文字以内にしてください。")
  }

  @Test func keepsTheDefaultWordingForTheDefaultLimit() {
    #expect(SentenceLengthLimitRule().description == "URL とコードを除いて一文は100文字以内にしてください。")
  }
}
