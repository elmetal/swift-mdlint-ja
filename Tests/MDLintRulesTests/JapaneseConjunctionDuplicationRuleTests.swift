import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("JapaneseConjunctionDuplicationRule")
struct JapaneseConjunctionDuplicationRuleTests {
  @Test func reportsDuplicatedConjunctionsInSingleParagraph() throws {
    let content = "朝起きた。そして昼は仕事をした。そして夜に寝た"
    let document = Document(parsing: content)
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 17)
    #expect(diagnostic.message.contains("同じ接続詞（そして）が連続して使われています。"))
  }

  @Test func reportsDuplicatesAcrossParagraphs() throws {
    let content = "1行目。\n\nそして朝起きた。昼は仕事をした。そして夜に寝た。\n\n5行目。"
    let document = Document(parsing: content)
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.line == 3)
    #expect(diagnostic.column == 17)
  }

  @Test func allowsDifferentConjunctions() {
    let content = "かな漢字変換により漢字が多用される傾向がある。しかし昼は仕事をした。だが夜に寝た。"
    let document = Document(parsing: content)
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func distinguishesConjunctionsSharingAPrefix() {
    let content = "それで終わりにした。それでも続きがあった。"
    let document = Document(parsing: content)
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test(arguments: [
    "またはAを使う。またはBを使う。",
    "または右を選ぶ。また、左も選べる。",
    "またも失敗した。またの機会にする。また、次回に試す。",
    "するときは注意する。するときに確認する。",
    "それに対して反論した。それにより結論が出た。",
    "それについて説明する。それに関して補足する。",
    "一方的に決めた。一方通行の道を進んだ。",
    "そのために準備した。そのための時間を取った。",
  ])
  func doesNotMistakeLongerWordsForConjunctions(content: String) {
    let document = Document(parsing: content)
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test(arguments: [
    ("また、Aを使う。また、Bを使う。", "また"),
    ("またAを使う。またBを使う。", "また"),
    ("すると雨が降った。すると風も吹いた。", "すると"),
    ("それに、安い。それに、速い。", "それに"),
    ("一方、Aは速い。一方、Bは遅い。", "一方"),
    ("そのため、延期した。そのため、中止した。", "そのため"),
  ])
  func stillReportsTheConjunctionsThemselves(content: String, conjunction: String) throws {
    let document = Document(parsing: content)
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.message.contains("（\(conjunction)）"))
  }

  @Test func reportsCorrectLineWithWindowsLineEndings() throws {
    let content = "朝起きた。\r\nそして昼は仕事をした。\r\nそして夜に寝た。\r\n"
    let document = Document(parsing: content)
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 3)
    #expect(diagnostic.column == 1)
  }

  @Test func ignoresConjunctionsInsideCodeBlocks() throws {
    // "しかし" inside the code block is not prose, so the two "そして" are consecutive.
    let content = "そして朝起きた。\n```\nしかし code。\n```\nそして夜に寝た。"
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.diagnostics(for: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 5)
    #expect(diagnostic.column == 1)
  }

  @Test func doesNotReportConjunctionsThatOnlyAppearInCodeBlocks() {
    let content = "そして朝起きた。\n\n    そして code。\n"
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func ignoresConjunctionsInsideInlineCode() throws {
    // "しかし" inside the code span is not prose, so the two "そして" are consecutive.
    let content = "そして朝起きた。値は ` しかし` です。そして夜に寝た。"
    let rule = JapaneseConjunctionDuplicationRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.message.contains("そして") == true)
  }
}
