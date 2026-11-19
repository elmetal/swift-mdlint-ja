import Foundation
import MDLintCore
import Markdown
import Testing

@testable import MDLintRules

/// Checks that the default rules, run through ``Linter``, leave code and raw HTML alone.
@Suite("Non-prose masking")
struct NonProseMaskingTests {
  private let linter = Linter(rules: DefaultRules.all())

  private func diagnostics(for content: String) -> [Diagnostic] {
    linter.lint(content: content, fileURL: sampleFileURL, applyFixes: false).0
  }

  private func fixed(_ content: String) -> String? {
    linter.lint(content: content, fileURL: sampleFileURL, applyFixes: true).1
  }

  @Test func reportsNothingInsideFencedCodeBlock() {
    let content = """
      本文です。

      ```swift
      // これは test です.
      let s = "ｶﾅ…にに、、、、、\u{200B}\u{0007}"
      # 見出しではない。
      #### 見出しではない
      `閉じていない
      ```

      続きの文です。

      """

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func reportsNothingInsideIndentedCodeBlock() {
    let content = "本文です。\n\n    これは test です.\n    ｶﾅ…\n\n続きの文です。\n"

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func reportsNothingInsideInlineCode() {
    let content = "書式は `これは test です.` や `ｶﾅ…にに` のように書きます。\n"

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func reportsNothingInsideHTML() {
    let content = """
      <!-- これは test です. ｶﾅ… -->

      本文です。<span title="ｶﾅ…">強調</span>します。

      """

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func stillReportsProseAroundCode() throws {
    let content = "```\ncode\n```\n\nこれは Test です `x`.\n"

    let diagnostics = diagnostics(for: content)

    #expect(
      Set(diagnostics.map(\.ruleID)) == [
        "ja.spacing.no-space-between-japanese-and-english", "ja.period.prefer-fullwidth",
      ])
    #expect(diagnostics.allSatisfy { $0.line == 5 })
  }

  @Test func fixLeavesCodeAndHTMLUntouched() {
    let content = """
      これは Test です.

      ```
      これは Test です.
      待って…\u{200B}
      ```

          これは Test です.

      <p>これは Test です.</p>

      `これは Test です.` と書く…

      """
    let expected = """
      これはTestです。

      ```
      これは Test です.
      待って…\u{200B}
      ```

          これは Test です.

      <p>これは Test です.</p>

      `これは Test です.` と書く……

      """

    #expect(fixed(content) == expected)
  }

  @Test func fixLeavesCodeSpansAfterAnUnclosedBacktickRunUntouched() {
    // The parser stops recognizing code spans after the unclosed "``", but
    // their contents must not be rewritten.
    let content = "閉じない ``コード と `a … b` と `これは Test です.` です\n"

    #expect(fixed(content) == content)
  }

  @Test func fixLeavesHeadingLikeLinesInCodeUntouched() {
    let content = "# 見出し。\n\n```sh\n# コメント。\n```\n"

    #expect(fixed(content) == "# 見出し\n\n```sh\n# コメント。\n```\n")
  }

  @Test func codeBlockDoesNotCountTowardSentenceLength() {
    let code = String(repeating: "a", count: 150)
    let content = "次のコードを実行します\n\n```\n\(code)\n\(code)\n```\n\n結果を確認します\n"

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func codeBlockDoesNotCountTowardCommaLimit() {
    let content = "一つ、二つ、三つ:\n```\na、b、c\n```\n四つ、五つ、六つです。\n"

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func inlineCodeDoesNotCountTowardSentenceLength() {
    // 98 characters of prose; the code span would bring the sentence to 108.
    let content = String(repeating: "あ", count: 95) + "`abcdefgh`です。\n"

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func inlineHTMLDoesNotCountTowardSentenceLength() {
    // 98 characters of prose; the tags would bring the sentence to 105.
    let content = String(repeating: "あ", count: 93) + "<b>強調</b>です。\n"

    #expect(diagnostics(for: content).isEmpty)
  }

  @Test func proseAroundInlineCodeStillCountsTowardSentenceLength() throws {
    // 101 characters of prose once the code span is left out.
    let content = String(repeating: "あ", count: 98) + "`abcdefgh`です。\n"

    let diagnostic = try #require(diagnostics(for: content).first)

    #expect(diagnostic.ruleID == "ja.sentence.max-length")
    #expect(diagnostic.message.contains("現在の文字数: 101"))
  }

  @Test func fixesLeavePlaceholdersInPlace() {
    let placeholders =
      String(MaskedSource.inlinePlaceholder) + String(MaskedSource.blockPlaceholder)
    let text = "# \(placeholders)\n\(placeholders) A \(placeholders).\n"

    for rule in DefaultRules.all() {
      let fixed = rule.fixed(text) ?? ""
      #expect(
        fixed.filter { placeholders.contains($0) } == text.filter { placeholders.contains($0) },
        "\(rule.id) changed the placeholders")
    }
  }
}
