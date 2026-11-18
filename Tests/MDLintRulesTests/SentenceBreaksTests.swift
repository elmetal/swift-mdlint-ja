import Markdown
import Testing

@testable import MDLintRules

@Suite("SentenceBreaks")
struct SentenceBreaksTests {
  private func blockStartLines(of content: String) -> [Int] {
    let breaks = Document(parsing: content).sentenceBreaks
    let lineCount = content.sourceLines.count
    return (1...lineCount).filter { breaks.startsBlock(atLine: $0) }
  }

  @Test func everyListItemStartsABlock() {
    let content = "- 一\n- 二\n  - 入れ子\n- 三\n"

    #expect(blockStartLines(of: content) == [1, 2, 3, 4])
  }

  @Test func softWrappedAndLazyContinuationLinesDoNotStartABlock() {
    let content = "一行目\n二行目\n\n- 項目\n続き\n\n> 引用\n続き\n"

    #expect(blockStartLines(of: content) == [1, 4, 7])
  }

  @Test func blocksWithoutBlankLinesBetweenThemStartOnTheirOwnLines() {
    let content = "# 見出し\n本文\n## 次の見出し\n- 項目\n> 引用\n"

    #expect(blockStartLines(of: content) == [1, 2, 3, 4, 5])
  }

  @Test func everyTableRowStartsABlock() {
    let content = "前の段落\n\n| 名前 | 説明 |\n| --- | --- |\n| 甲 | 乙 |\n| 丙 | 丁 |\n\n後の段落\n"

    let lines = blockStartLines(of: content)

    #expect(lines.contains(3))
    #expect(lines.contains(5))
    #expect(lines.contains(6))
    #expect(lines.contains(8))
  }

  @Test func pipesSeparateCellsOnlyInsideATable() {
    let content = "a | b\n\n| 名前 | 説明 |\n| --- | --- |\n| 甲 \\| 乙 | 丙 |\n\nc | d\n"
    let breaks = Document(parsing: content).sentenceBreaks

    #expect(!breaks.separatesTableCells("|", after: " ", onLine: 1))
    #expect(breaks.separatesTableCells("|", after: " ", onLine: 3))
    #expect(breaks.separatesTableCells("|", after: " ", onLine: 4))
    #expect(breaks.separatesTableCells("|", after: nil, onLine: 5))
    #expect(!breaks.separatesTableCells("|", after: "\\", onLine: 5))
    #expect(!breaks.separatesTableCells("、", after: " ", onLine: 5))
    #expect(!breaks.separatesTableCells("|", after: " ", onLine: 7))
  }
}
