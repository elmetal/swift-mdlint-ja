import Foundation
import MDLintCore
import Markdown
import Testing

@testable import MDLintRules

/// Checks where the comma and sentence-length rules end a sentence.
@Suite("Sentence boundaries")
struct SentenceBoundaryTests {
  private func commaDiagnostics(for content: String) -> [Diagnostic] {
    JapaneseCommaLimitRule().check(
      document: Document(parsing: content), fileURL: sampleFileURL, originalText: content)
  }

  private func lengthDiagnostics(for content: String) -> [Diagnostic] {
    SentenceLengthLimitRule().check(
      document: Document(parsing: content), fileURL: sampleFileURL, originalText: content)
  }

  // MARK: Commas

  @Test(arguments: [
    "- 一、二\n- 三、四\n- 五、六\n",
    "1. 一、二\n2. 三、四\n   - 五、六\n   - 七、八\n",
    "# 一、二、三\n四、五、六\n## 七、八、九\n",
    "> 一、二、三\n- 四、五、六\n",
    "| 甲、乙 | 一、二 |\n| --- | --- |\n| 丙、丁 | 三、四 |\n| 戊、己 | 五、六 |\n",
    "一、二、三. 四、五、六.\n",
    "一、二、三.\n四、五、六\n",
  ])
  func commasAreCountedSeparatelyOnEachSideOfABoundary(content: String) {
    #expect(commaDiagnostics(for: content).isEmpty)
  }

  @Test func commasAreStillCountedAcrossSoftWrappedLines() {
    #expect(commaDiagnostics(for: "一、二、\n三、四、五\n").map(\.line) == [2])
    #expect(commaDiagnostics(for: "- 一、二、\n三、四、五\n").map(\.line) == [2])
    #expect(commaDiagnostics(for: "- 一、二、\n  三、四、五\n- 六\n").map(\.line) == [2])
  }

  @Test func commasAreCountedWithinOneTableCell() {
    let content = "| 名前 | 説明 |\n| --- | --- |\n| 甲 | 一、二、三、四、五 |\n"

    #expect(commaDiagnostics(for: content).map(\.line) == [3])
  }

  @Test func escapedPipeDoesNotSplitATableCell() {
    let content = "| 名前 | 説明 |\n| --- | --- |\n| 一、二、三 \\| 四、五、六 | 乙 |\n"

    #expect(commaDiagnostics(for: content).map(\.line) == [3])
  }

  @Test func pipeOutsideATableDoesNotEndTheSentence() {
    #expect(commaDiagnostics(for: "一、二、三 | 四、五、六\n").count == 1)
  }

  @Test func periodWithoutFollowingWhitespaceDoesNotEndTheSentence() {
    #expect(commaDiagnostics(for: "バージョン1.2では、一、二、三、四です\n").count == 1)
  }

  // MARK: Sentence length

  @Test func listItemsAreMeasuredSeparately() {
    let item = "- " + String(repeating: "あ", count: 40) + "\n"

    #expect(lengthDiagnostics(for: String(repeating: item, count: 4)).isEmpty)
  }

  @Test func headingAndFollowingParagraphAreMeasuredSeparately() {
    let content =
      "# " + String(repeating: "あ", count: 60) + "\n" + String(repeating: "い", count: 60) + "\n"

    #expect(lengthDiagnostics(for: content).isEmpty)
  }

  @Test func tableRowsAndCellsAreMeasuredSeparately() {
    let cell = String(repeating: "あ", count: 60)
    let content = "| 名前 | 説明 |\n| --- | --- |\n| \(cell) | \(cell) |\n| \(cell) | \(cell) |\n"

    #expect(lengthDiagnostics(for: content).isEmpty)
  }

  @Test func longTableCellIsStillReported() {
    let content = "| 名前 | 説明 |\n| --- | --- |\n| 甲 | \(String(repeating: "あ", count: 120)) |\n"

    #expect(lengthDiagnostics(for: content).map(\.line) == [3])
  }

  @Test func softWrappedLinesAreStillMeasuredAsOneSentence() {
    let line = String(repeating: "あ", count: 60)

    #expect(lengthDiagnostics(for: "\(line)\n\(line)\n").map(\.line) == [2])
    #expect(lengthDiagnostics(for: "- \(line)\n  \(line)\n- 次\n").map(\.line) == [2])
  }

  @Test func englishSentencesAreMeasuredSeparately() {
    let sentence = "This sentence is short enough to pass."
    let paragraph = Array(repeating: sentence, count: 5).joined(separator: " ")
    let wrapped = Array(repeating: sentence, count: 5).joined(separator: "\n")

    #expect(paragraph.count > 100)
    #expect(lengthDiagnostics(for: paragraph + "\n").isEmpty)
    #expect(lengthDiagnostics(for: wrapped + "\n").isEmpty)
  }

  @Test func longEnglishSentenceIsStillReported() {
    let content = Array(repeating: "word", count: 30).joined(separator: " ") + ". Short one.\n"

    #expect(lengthDiagnostics(for: content).count == 1)
  }

  @Test func periodWithoutFollowingWhitespaceDoesNotSplitTheSentence() throws {
    // 3.14 and example.com contain periods that do not end the sentence.
    let content =
      "円周率は3.14で" + String(repeating: "あ", count: 50) + "example.comを"
      + String(repeating: "い", count: 40) + "。\n"

    let diagnostic = try #require(lengthDiagnostics(for: content).first)

    #expect(diagnostic.message.contains("現在の文字数: \(content.count - 1)"))
  }
}
