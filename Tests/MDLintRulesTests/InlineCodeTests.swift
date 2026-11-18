import Markdown
import Testing

@testable import MDLintRules

@Suite("InlineCode")
struct InlineCodeTests {
  /// Returns the source text of the inline code span covering the first `marker`.
  private func span(covering marker: Character, in source: String) -> String? {
    let ranges = Document(parsing: source).inlineCodeRanges(in: source)
    guard let index = source.firstIndex(of: marker) else { return nil }
    return ranges.range(containing: index).map { String(source[$0]) }
  }

  @Test func coversDelimitersAndContent() throws {
    let source = "これは `code` です"
    let ranges = Document(parsing: source).inlineCodeRanges(in: source)
    let opening = try #require(source.firstIndex(of: "`"))

    #expect(ranges.contains(opening))
    #expect(span(covering: "c", in: source) == "`code`")
    #expect(span(covering: "こ", in: source) == nil)
    #expect(span(covering: "で", in: source) == nil)
  }

  @Test func handlesLongerDelimitersAndMultibyteText() {
    let source = "日本語`` a ` b ``日本語 `二つ目` 終わり"

    #expect(span(covering: "a", in: source) == "`` a ` b ``")
    #expect(span(covering: "二", in: source) == "`二つ目`")
    #expect(span(covering: "終", in: source) == nil)
  }

  @Test func findsSpansNestedInOtherMarkup() {
    let source =
      "- **強調 `a`** と [リンク `b`](url)\n\n> 引用 `c`\n\n| x | y |\n|---|---|\n| 表 | `d` |\n"

    #expect(span(covering: "a", in: source) == "`a`")
    #expect(span(covering: "b", in: source) == "`b`")
    #expect(span(covering: "c", in: source) == "`c`")
    #expect(span(covering: "d", in: source) == "`d`")
  }

  @Test func coversSpansThatContinueOnTheNextLine() {
    let source = "複数行 `span\r\n続き` です"

    #expect(span(covering: "s", in: source) == "`span\r\n続き`")
    #expect(span(covering: "続", in: source) == "`span\r\n続き`")
    #expect(span(covering: "で", in: source) == nil)
  }

  @Test func fallsBackToScanningWhenReportedColumnsAreShiftedByATab() {
    // The parser expands the leading tab when it reports columns.
    let source = "本文\n\tタブ `c2` です"

    #expect(span(covering: "c", in: source) == "`c2`")
    #expect(span(covering: "タ", in: source) == nil)
  }

  @Test func coversMultilineSpansInsideListsAndBlockQuotes() {
    // The parser reports the end column relative to the stripped indentation or
    // ">" marker, so these spans are resolved by scanning the reported lines.
    let list = "- 項目 `list\n  続き` です `x`\n  次の `y\n  z` 行"
    let quote = "> 引用 `quote\n> 続き` です"

    #expect(span(covering: "l", in: list) == "`list\n  続き`")
    #expect(span(covering: "x", in: list) == "`x`")
    #expect(span(covering: "z", in: list) == "`y\n  z`")
    #expect(span(covering: "で", in: list) == nil)
    #expect(span(covering: "q", in: quote) == "`quote\n> 続き`")
    #expect(span(covering: "で", in: quote) == nil)
  }

  @Test func ignoresCodeBlocksAndUnmatchedBackticks() {
    let source = "閉じていない `a\n\n```\nlet b = `c`\n```\n"

    #expect(span(covering: "a", in: source) == nil)
    #expect(span(covering: "c", in: source) == nil)
  }
}

@Suite("BacktickScanner")
struct BacktickScannerTests {
  @Test func pairsRunsOfEqualLength() {
    let line: Substring = "`a` と `` b ` c `` と \\` と `d"

    let result = BacktickScanner.scan(line)

    #expect(result.spans.map { String(line[$0]) } == ["`a`", "`` b ` c ``"])
    #expect(result.firstUnmatched.map { String(line[$0...]) } == "`d")
  }

  @Test func treatsKnownSpansAsMatched() throws {
    // The first backtick belongs to a span that continues on the next line.
    let source = "一行目 `続く\n続き` と `x"
    let lines = source.sourceLines
    let known = Document(parsing: source).inlineCodeRanges(in: source)

    #expect(BacktickScanner.scan(lines[0], skipping: known).firstUnmatched == nil)
    let unmatched = try #require(BacktickScanner.scan(lines[1], skipping: known).firstUnmatched)
    #expect(String(lines[1][unmatched...]) == "`x")
  }
}
