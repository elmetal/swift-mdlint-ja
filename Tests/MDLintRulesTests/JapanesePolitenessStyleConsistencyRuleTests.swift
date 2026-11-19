import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("JapanesePolitenessStyleConsistencyRule")
struct JapanesePolitenessStyleConsistencyRuleTests {
  @Test func reportsDearuWhenDesumasuIsMajority() throws {
    let content = "これはテストです。\nこの文も丁寧語です。\nこれは事実である。"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 3)
    #expect(diagnostic.ruleID == rule.id)
  }

  @Test func reportsDesumasuWhenDearuPreferred() throws {
    let content = "これは事実である。\n別の文だ。\nしかし説明します。"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .dearu)

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 3)
    #expect(diagnostic.ruleID == rule.id)
  }

  @Test func returnsEmptyWhenStylesAreBalancedAndAuto() {
    let content = "これはテストです。\nこれは報告である。"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func ignoresLinesInsideCodeBlocks() {
    let content = "これはテストです。\n```\nこれは報告である。\n```"
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .desumasu)

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func detectsDesumasuStyleWithTrailingPunctuation() throws {
    let content = "これはテストでした！  "
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .dearu)

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 7)
    #expect(diagnostic.ruleID == rule.id)
  }

  @Test func detectsDearuStyleWithTrailingBrackets() throws {
    let content = "この章は概要である。」\nこの段落は丁寧に説明します。"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .desumasu)

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 7)
    #expect(diagnostic.ruleID == rule.id)
  }

  @Test func ignoresSentencesWithoutKnownSuffixes() {
    let content = "テストする。\nこれは丁寧に説明します。"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .desumasu)

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func classifiesEverySentenceOnALine() throws {
    let content = "これは事実である。しかし説明します。結論は明らかだ。"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    // Two plain sentences and one polite sentence: the polite one is the minority.
    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 16)
    #expect(diagnostic.message.contains("この文は敬体"))
  }

  @Test func reportsEveryMismatchedSentenceOnALine() {
    let content = "これはテストです。これは事実である！別の文だ？最後は丁寧に説明します"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .desumasu)

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.column) == [15, 22])
  }

  @Test(arguments: [
    "彼は「行きます。」と言った。結論は明らかだ。",
    "注記（これは補足です。）を付けた。結論は明らかだ。",
    "『急ぎましょう！』と叫んだ。結論は明らかだ。",
  ])
  func doesNotClassifyQuotedSentencesOnTheirOwn(content: String) {
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .dearu)

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func handlesWindowsLineEndings() throws {
    let content = "これはテストです。\r\nこの文も丁寧語です。\r\nこれは事実である。\r\n"
    let document = Document(parsing: content)
    let rule = JapanesePolitenessStyleConsistencyRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 3)
  }

  @Test func ignoresTildeFencedAndIndentedCodeBlocks() {
    let content = "これはテストです。\n\n~~~\nこれは報告である。\n~~~\n\n    これも報告である。\n"
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .desumasu)

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func doesNotClassifyLinesByInlineCodeContents() {
    let content = "これは事実である。\n出力は `完了です`\n"
    let rule = JapanesePolitenessStyleConsistencyRule(preferredStyle: .dearu)

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }
}
