import Foundation
import MDLintCore
import Markdown
import Testing

@testable import MDLintRules

/// The parts of a fix-it that locate and describe the edit.
private func edit(
  _ line: Int, _ column: Int, length: Int, with replacement: String, _ description: String
) -> FixIt {
  FixIt(
    description: description, line: line, column: column, endLine: line,
    endColumn: column + length, replacement: replacement)
}

@Suite("Fix-its of the rules")
struct RuleFixItTests {
  @Test func periodRuleReplacesThePeriodAndKeepsTrailingSpaces() {
    let diagnostics = JapanesePeriodRule().diagnostics(for: "これは文です\nこれも文です.  \n")

    #expect(diagnostics.map(\.fixIt) == [edit(2, 7, length: 1, with: "。", "末尾の . を「。」に置換")])
  }

  @Test func spacingRuleDeletesEachRunOfSpaces() {
    let diagnostics = JapaneseEnglishSpacingRule().diagnostics(for: "本文\nこれは  Test \tです\n")

    #expect(
      diagnostics.map(\.fixIt) == [
        edit(2, 4, length: 2, with: "", "スペースを削除"),
        edit(2, 10, length: 2, with: "", "スペースを削除"),
      ])
  }

  @Test func ellipsisRuleReplacesTheWholeRun() {
    let diagnostics = JapaneseEllipsisRule().diagnostics(for: "そして…こう………なる……。\n")

    #expect(
      diagnostics.map(\.fixIt) == [
        edit(1, 4, length: 1, with: "……", "「…」を「……」に置換"),
        edit(1, 7, length: 3, with: "…………", "「………」を「…………」に置換"),
      ])
  }

  @Test func headingRuleDeletesThePunctuation() {
    let diagnostics = HeadingTerminalPunctuationRule().diagnostics(for: "本文。\n\n## 見出し。\n")

    #expect(diagnostics.map(\.fixIt) == [edit(3, 7, length: 1, with: "", "末尾の句読点を除去")])
  }

  @Test func zeroWidthSpaceRuleDeletesTheCharacter() {
    let diagnostics = ZeroWidthSpaceRule().diagnostics(for: "一行目\n二\u{200B}行目\u{200B}\n")

    #expect(
      diagnostics.map(\.fixIt) == [
        edit(2, 2, length: 1, with: "", "ゼロ幅スペースを削除"),
        edit(2, 5, length: 1, with: "", "ゼロ幅スペースを削除"),
      ])
  }

  @Test func controlCharacterRuleDeletesTheCharacter() {
    let diagnostics = ControlCharacterRule().diagnostics(for: "a\u{07}b\tc\u{0C}\n")

    #expect(
      diagnostics.map(\.fixIt) == [
        edit(1, 2, length: 1, with: "", "制御文字を削除"),
        edit(1, 6, length: 1, with: "", "制御文字を削除"),
      ])
  }

  @Test func fixItsStartWhereTheirDiagnosticsAre() {
    let content = "# 見出し.\n\nこれは Test です.\u{200B} そして…\u{07}\n"

    let diagnostics = Linter(rules: DefaultRules.all())
      .lint(content: content, fileURL: sampleFileURL, applyFixes: false).0

    let fixable = diagnostics.filter { $0.fixIt != nil }
    #expect(fixable.count >= 6)
    for diagnostic in fixable {
      #expect(diagnostic.fixIt?.line == diagnostic.line)
      #expect(diagnostic.fixIt?.column == diagnostic.column)
    }
  }

  @Test func rulesWithoutFixesReportNoFixIts() {
    let content = "ﾊﾝｶｸ、一、二、三、四。しかし、しかし。\n\n### 飛ばした見出し\n"
    let fixableRuleIDs: Set<String> = [
      "ja.ellipsis.prefer-double", "ja.period.prefer-fullwidth",
      "ja.heading.no-terminal-punctuation", "ja.spacing.no-space-between-japanese-and-english",
      "md.whitespace.no-zero-width-space", "md.characters.no-control",
    ]

    let diagnostics = Linter(rules: DefaultRules.all())
      .lint(content: content, fileURL: sampleFileURL, applyFixes: false).0

    #expect(!diagnostics.isEmpty)
    for diagnostic in diagnostics where !fixableRuleIDs.contains(diagnostic.ruleID) {
      #expect(diagnostic.fixIt == nil)
    }
  }
}

@Suite("Fixing with every rule")
struct DefaultRulesFixingTests {
  private func fixed(_ content: String) -> String? {
    Linter(rules: DefaultRules.all())
      .lint(content: content, fileURL: sampleFileURL, applyFixes: true).1
  }

  @Test func fixesAHeadingThatEndsInAHalfWidthPeriod() {
    // The period rule and the heading rule both have a fix for the same
    // character. Whichever is applied first, the heading ends up bare.
    #expect(fixed("# これは見出しです.\n\n本文です。\n") == "# これは見出しです\n\n本文です。\n")
  }

  @Test func fixesWhatAnEarlierFixUncovers() {
    // The space only separates Japanese from Latin text once the zero-width
    // space between them is gone.
    #expect(fixed("これは\u{200B} Test です。\n") == "これはTestです。\n")
  }

  @Test func fixingAgainChangesNothing() throws {
    let content = "# 見出し.\n\nこれは Test です.\u{200B} そして… 終わり\u{07}.\n\n- 項目 A です.\n"

    let once = try #require(fixed(content))

    #expect(once != content)
    #expect(fixed(once) == once)
  }

  @Test func leavesCodeAndHTMLUntouched() {
    let content = """
      これは Test です.

      ```
      これは Test です.…
      ```

      `これは Test です.` と <b>これは Test です.</b> です.

      """
    let expected = """
      これはTestです。

      ```
      これは Test です.…
      ```

      `これは Test です.` と <b>これはTestです.</b> です。

      """

    #expect(fixed(content) == expected)
  }
}
