import Foundation
import Markdown
import Testing

@testable import MDLintCore

private let inline = String(MaskedSource.inlinePlaceholder)
private let block = String(MaskedSource.blockPlaceholder)

private func mask(_ content: String) -> MaskedSource {
  MaskedSource(content: content, document: Document(parsing: content))
}

@Suite("MaskedSource")
struct MaskedSourceTests {
  @Test func leavesProseUntouched() {
    let content = "# 見出し\n\nこれは**本文**です。\n"

    #expect(mask(content).text == content)
  }

  @Test func masksInlineCodeIncludingBackticks() {
    let source = mask("日本語 `code` です。")

    #expect(source.text == "日本語 " + String(repeating: inline, count: 6) + " です。")
  }

  @Test func masksInlineCodeWithLongerDelimiters() {
    let source = mask("前 `` a ` b `` 後")

    #expect(source.text == "前 " + String(repeating: inline, count: 11) + " 後")
  }

  @Test func masksFencedCodeBlockAndKeepsLineBreaks() {
    let source = mask("前の文。\n\n```swift\nlet a = 1\n```\n\n次の文。\n")

    let expected = [
      "前の文。",
      "",
      String(repeating: block, count: 8),
      String(repeating: block, count: 9),
      String(repeating: block, count: 3),
      "",
      "次の文。",
      "",
    ].joined(separator: "\n")
    #expect(source.text == expected)
  }

  @Test func masksUnclosedFencedCodeBlockUntilEndOfDocument() {
    let source = mask("文。\n\n```\ncode\n")

    #expect(
      source.text == "文。\n\n" + String(repeating: block, count: 3) + "\n"
        + String(repeating: block, count: 4) + "\n")
  }

  @Test func masksIndentedCodeBlock() {
    let source = mask("文。\n\n    code\n\n次。\n")

    #expect(source.text == "文。\n\n    " + String(repeating: block, count: 4) + "\n\n次。\n")
  }

  @Test func masksCodeBlockNestedInListAndBlockQuote() {
    let list = mask("- 項目\n\n  ```\n  code\n  ```\n")
    #expect(!list.text.contains("code"))
    #expect(list.text.hasPrefix("- 項目\n\n  " + String(repeating: block, count: 3) + "\n"))

    let quote = mask("> ```\n> code\n> ```\n")
    #expect(!quote.text.contains("code"))
    #expect(quote.text.hasPrefix("> " + String(repeating: block, count: 3) + "\n"))
  }

  @Test func masksHTMLBlockAndInlineHTML() {
    let source = mask("<div>\n日本語\n</div>\n\n本文<br>続き\n")

    let expected = [
      String(repeating: block, count: 5),
      String(repeating: block, count: 3),
      String(repeating: block, count: 6),
      "",
      "本文" + String(repeating: inline, count: 4) + "続き",
      "",
    ].joined(separator: "\n")
    #expect(source.text == expected)
  }

  @Test func masksInlineCodeInsideTableCells() {
    let source = mask("| a | b |\n|---|---|\n| 日本語 `x y` | `z` |\n")

    let lastRow =
      "| 日本語 " + String(repeating: inline, count: 5) + " | "
      + String(repeating: inline, count: 3) + " |"
    #expect(source.text == "| a | b |\n|---|---|\n" + lastRow + "\n")
  }

  /// Shows inline placeholders as `◆` and block placeholders as `■`.
  private func picture(_ content: String) -> String {
    mask(content).text
      .replacingOccurrences(of: inline, with: "◆")
      .replacingOccurrences(of: block, with: "■")
  }

  // The parser reports wrong columns for the inline nodes in these documents.
  @Test(arguments: [
    // A code span that continues on the next line of a list item or block quote.
    ("- 項目 `multi\n  line` 後ろ\n", "- 項目 ◆◆◆◆◆◆\n◆◆◆◆◆◆◆ 後ろ\n"),
    ("> 引用 `multi\n> line` 後ろ\n", "> 引用 ◆◆◆◆◆◆\n◆◆◆◆◆◆◆ 後ろ\n"),
    ("> > 引用 `multi\n> > line\n> > three` 後ろ\n", "> > 引用 ◆◆◆◆◆◆\n◆◆◆◆◆◆◆◆\n◆◆◆◆◆◆◆◆◆◆ 後ろ\n"),
    (
      "- 項目 ``multi ` x\n  line`` 後ろ `z` 後ろ\n",
      "- 項目 ◆◆◆◆◆◆◆◆◆◆◆\n◆◆◆◆◆◆◆◆ 後ろ ◆◆◆ 後ろ\n"
    ),
    // The later lines of a paragraph whose first line is indented.
    ("   日本語 `code` です。\n続き `x y` 後ろ\n", "   日本語 ◆◆◆◆◆◆ です。\n続き ◆◆◆◆◆ 後ろ\n"),
    // Escaped pipes in a table cell.
    (
      "| a | b |\n|---|---|\n| \\| \\| `x y` 後ろ | `p` \\| `q \\| r` 後ろ |\n",
      "| a | b |\n|---|---|\n| \\| \\| ◆◆◆◆◆ 後ろ | ◆◆◆ \\| ◆◆◆◆◆◆◆◆ 後ろ |\n"
    ),
    // Inline HTML that continues on the next line.
    ("本文 <span\n title=\"x\">中</span> 後ろ\n", "本文 ◆◆◆◆◆\n◆◆◆◆◆◆◆◆◆◆◆中◆◆◆◆◆◆◆ 後ろ\n"),
    ("- 項目 <span\n  title=\"x\">中</span> 後ろ\n", "- 項目 ◆◆◆◆◆\n◆◆◆◆◆◆◆◆◆◆◆◆中◆◆◆◆◆◆◆ 後ろ\n"),
    // Columns that are already right must keep working.
    ("- 項目\n  続き `a b` 後ろ\n", "- 項目\n  続き ◆◆◆◆◆ 後ろ\n"),
    ("-\t項目 `a b` 後ろ\n", "-\t項目 ◆◆◆◆◆ 後ろ\n"),
    ("同じ `a` と `a` と ` a ` です\n", "同じ ◆◆◆ と ◆◆◆ と ◆◆◆◆◆ です\n"),
    ("\\`a\\` は `a` ではない\n", "\\`a\\` は ◆◆◆ ではない\n"),
    ("**強調 `a b`** と [リンク `c d`](http://x)\n", "**強調 ◆◆◆◆◆** と [リンク ◆◆◆◆◆](http://x)\n"),
    ("-\t```\n\tcode\n\t```\n\n後ろ `z`\n", "-\t■■■\n■■■■■\n■■■■\n\n後ろ ◆◆◆\n"),
  ])
  func locatesInlineNodesWithoutTrustingColumns(content: String, expected: String) {
    #expect(picture(content) == expected)
    #expect(mask(content).unmasking(mask(content).text) == content)
  }

  @Test func keepsLineAndColumnOfFollowingText() {
    let content = "あ `か゚👨‍👩‍👧` い\r\n```\r\ncode\r\n```\r\nう\r\n"
    let source = mask(content)

    let originalLines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    let maskedLines = source.text.split(
      omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    #expect(maskedLines.count == originalLines.count)
    for (original, masked) in zip(originalLines, maskedLines) {
      #expect(masked.count == original.count)
    }
    let expectedFirstLine: String = "あ " + String(repeating: inline, count: 4) + " い"
    #expect(maskedLines.first.map(String.init) == expectedFirstLine)
  }

  @Test(arguments: [
    "",
    "本文だけ。",
    "日本語 `code` です。\n",
    "前の文。\n\n```swift\nlet a = 1\n```\n\n次の文。\n",
    "文\n```\ncode",
    "文。\n\n    indented code\n    more\n\n次。\n",
    "- 項目\n\n  ```\n  code\n  ```\n",
    "> ```\n> code\n> ```\n",
    "<div>\n日本語\n</div>\n\n本文 <br> 続き <!-- c --> 終わり\n",
    "| a | b |\n|---|---|\n| 日本語 `x y` | `z` |\n",
    "前 `` a ` b `` 後\r\n```\r\ncode\r\n```\r\n後\r\n",
    "前 `multi\nline` 後\n",
    "あ `か゚👨‍👩‍👧` い\n",
    "本文に \u{FFFC} と \u{E000} がある `\u{FFFC}\u{E000}` 文。\n\n```\n\u{E000}\u{FFFC}\n```\n",
  ])
  func unmaskingRestoresTheOriginal(content: String) {
    let source = mask(content)

    #expect(source.unmasking(source.text) == content)
  }

  @Test func unmaskingKeepsEditsMadeToProse() {
    let source = mask("これは Test です `a b` .\n")
    let edited = source.text
      .replacingOccurrences(of: "これは Test です", with: "これはTestです")
      .replacingOccurrences(of: " .", with: "。")

    #expect(source.unmasking(edited) == "これはTestです `a b`。\n")
  }

  @Test func unmaskingFailsWhenPlaceholderIsRemoved() {
    let source = mask("前 `code` 後")

    #expect(source.unmasking(source.text.replacing(inline, with: "", maxReplacements: 1)) == nil)
    #expect(source.unmasking(source.text.replacing(inline, with: "")) == nil)
  }

  @Test func unmaskingFailsWhenPlaceholderIsAdded() {
    let source = mask("前 `code` 後")

    #expect(source.unmasking(source.text + inline) == nil)
  }

  @Test func unmaskingFailsWhenPlaceholderKindsAreReordered() {
    let source = mask("`a`\n\n```\nb\n```\n")
    let swapped = String(source.text.reversed())

    #expect(source.unmasking(swapped) == nil)
  }
}

@Suite("Linter masking")
struct LinterMaskingTests {
  @Test func rulesDoNotSeeCode() throws {
    let linter = Linter(rules: [FindWordRule(word: "bad")])
    let content = "`bad` bad\n\n```\nbad\n```\n"

    let (diagnostics, _) = linter.lint(content: content, fileURL: fileURL, applyFixes: false)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 7)
  }

  @Test func fixesDoNotTouchCode() {
    let linter = Linter(rules: [FindWordRule(word: "bad")])
    let content = "`bad` bad\n\n```\nbad\n```\n\n<p>bad</p>\n"

    let (_, fixed) = linter.lint(content: content, fileURL: fileURL, applyFixes: true)

    #expect(fixed == "`bad` good\n\n```\nbad\n```\n\n<p>bad</p>\n")
  }

  @Test func dropsFixThatDisturbsPlaceholders() {
    let linter = Linter(rules: [PlaceholderEatingRule(), FindWordRule(word: "bad")])
    let content = "`code` bad\n"

    let (_, fixed) = linter.lint(content: content, fileURL: fileURL, applyFixes: true)

    #expect(fixed == "`code` good\n")
  }

  @Test func returnsOriginalWhenNothingIsFixable() {
    let linter = Linter(rules: [])
    let content = "`code`\r\n\r\n```\r\ncode\r\n```\r\n"

    let (_, fixed) = linter.lint(content: content, fileURL: fileURL, applyFixes: true)

    #expect(fixed == content)
  }
}

private let fileURL = URL(fileURLWithPath: "/tmp/masked.md")

private struct FindWordRule: Rule, AutoFixable {
  let id = "test.find-word"
  let description = "Reports the first occurrence of a word and replaces all of them"
  let word: String

  func check(document _: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    guard let range = originalText.range(of: word) else { return [] }
    let prefix = originalText[..<range.lowerBound]
    let line = prefix.filter { $0 == "\n" }.count + 1
    let column =
      (prefix.split(separator: "\n", omittingEmptySubsequences: false).last?.count ?? 0) + 1
    return [Diagnostic(file: fileURL, line: line, column: column, ruleID: id, message: word)]
  }

  func fixing(originalText: String) -> String {
    originalText.replacingOccurrences(of: word, with: "good")
  }
}

private struct PlaceholderEatingRule: Rule, AutoFixable {
  let id = "test.eat-placeholders"
  let description = "A misbehaving fix that deletes placeholder characters"

  func check(document _: Document, fileURL _: URL, originalText _: String) -> [Diagnostic] { [] }

  func fixing(originalText: String) -> String {
    originalText.replacingOccurrences(of: String(MaskedSource.inlinePlaceholder), with: "")
  }
}
