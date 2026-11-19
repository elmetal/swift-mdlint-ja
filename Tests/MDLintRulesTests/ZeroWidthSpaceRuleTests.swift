import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("ZeroWidthSpaceRule")
struct ZeroWidthSpaceRuleTests {
  @Test
  func reportsZeroWidthSpaces() throws {
    let content = "行頭\u{200B}に含まれています"
    let document = Document(parsing: content)
    let rule = ZeroWidthSpaceRule()

    let diagnostics = rule.check(
      document: document,
      fileURL: sampleFileURL,
      originalText: content
    )

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 3)
  }

  @Test
  func fixRemovesZeroWidthSpaces() {
    let content = "前\u{200B}後\n別の行"
    let rule = ZeroWidthSpaceRule()

    let fixed = rule.fixed(content)

    #expect(fixed == "前後\n別の行")
  }

  @Test
  func passesWhenNoZeroWidthSpacesArePresent() {
    let content = "ゼロ幅スペースなし"
    let document = Document(parsing: content)
    let rule = ZeroWidthSpaceRule()

    let diagnostics = rule.check(
      document: document,
      fileURL: sampleFileURL,
      originalText: content
    )

    #expect(diagnostics.isEmpty)
  }

  @Test func countsColumnsInCharacters() {
    // The family emoji is one character made of five scalars.
    let content = "👨\u{200D}👩\u{200D}👧\u{200B}後\u{200B}"
    let document = Document(parsing: content)
    let rule = ZeroWidthSpaceRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.column) == [2, 4])
  }

  @Test func reportsCorrectLineWithLoneCarriageReturns() {
    let content = "一行目\r二行目\u{200B}\r三行目"
    let document = Document(parsing: content)
    let rule = ZeroWidthSpaceRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [2])
    #expect(diagnostics.map(\.column) == [4])
  }
}
