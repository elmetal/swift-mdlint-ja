import Testing

@testable import MDLintRules

@Suite("SourceText")
struct SourceTextTests {
  @Test func splitsLinesOnEveryLineTerminator() {
    let text = "一行目\n二行目\r\n三行目\r四行目"

    #expect(text.sourceLines == ["一行目", "二行目", "三行目", "四行目"])
  }

  @Test func mappingPreservesLineTerminators() {
    let text = "a\nb\r\nc\n"

    #expect(text.mappingSourceLines { $0.uppercased() } == "A\nB\r\nC\n")
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

  @Test func mappingCopiesSkippedLinesVerbatim() {
    let text = "a\nb\r\nc"

    #expect(text.mappingSourceLines(skipping: [2]) { $0.uppercased() } == "A\nb\r\nC")
  }
}
