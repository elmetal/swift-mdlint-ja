import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("InlineBacktickClosureRule")
struct InlineBacktickClosureRuleTests {
  @Test func reportsLineWithUnclosedBacktick() throws {
    let content = "これは `テストです"
    let document = Document(parsing: content)
    let rule = InlineBacktickClosureRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
  }

  @Test func passesWhenBackticksAreClosed() {
    let content =
      """
      これは `テスト` です
      ```
      コードブロック内の ` は無視
      ```
      """
    let document = Document(parsing: content)
    let rule = InlineBacktickClosureRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func matchesBacktickRunsByLength() {
    // A double-backtick span may contain a single backtick, and an escaped
    // backtick is plain text.
    let content = "`` a ` b `` は有効です\nこれは \\` ただの文字です"
    let document = Document(parsing: content)
    let rule = InlineBacktickClosureRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func reportsRunWithoutCloserOfSameLength() throws {
    let content = "これは ``コード` です"
    let document = Document(parsing: content)
    let rule = InlineBacktickClosureRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.column == 5)
  }

  @Test func ignoresTildeFencedAndIndentedCodeBlocks() {
    let content = "本文\n\n~~~\nlet s = `unclosed\n~~~\n\n    echo `date\n"
    let document = Document(parsing: content)
    let rule = InlineBacktickClosureRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }
}
