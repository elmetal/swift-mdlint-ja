import MDLintCore
import Testing

@testable import MDLintRules

@Suite("SourceText")
struct SourceTextTests {
  @Test func splitsLinesOnEveryLineTerminator() {
    let text = "一行目\n二行目\r\n三行目\r四行目"

    #expect(text.sourceLines == ["一行目", "二行目", "三行目", "四行目"])
  }

  @Test func fixItLocatesAPartOfALineInCharacters() throws {
    let text = "一行目\r\n二👨‍👩‍👧行目"
    let line = try #require(text.sourceLines.last)
    let range = try #require(line.range(of: "行目"))

    let fixIt = FixIt(description: "置換", replacing: range, in: line, lineNumber: 2, with: "x")

    #expect(
      fixIt
        == FixIt(description: "置換", line: 2, column: 3, endLine: 2, endColumn: 5, replacement: "x"))
  }

  @Test func computesLineAndColumnAcrossWindowsLineEndings() throws {
    let text = "一行目\r\n二行目"
    let index = try #require(text.firstIndex(of: "目").flatMap { _ in text.lastIndex(of: "目") })

    let position = text.lineAndColumn(of: index)

    #expect(position.line == 2)
    #expect(position.column == 3)
  }

  @Test func ignoresTrailingSpacesAndTabs() {
    let text = "本文 \t "

    #expect(text[..<text.endIndexIgnoringTrailingSpacesAndTabs] == "本文")
  }
}
