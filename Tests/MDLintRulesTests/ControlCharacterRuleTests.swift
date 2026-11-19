import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("ControlCharacterRule")
struct ControlCharacterRuleTests {
  @Test func reportsControlCharacters() throws {
    let content = "正常なテキスト\u{0001}"
    let document = Document(parsing: content)
    let rule = ControlCharacterRule()

    let diagnostics = rule.check(
      document: document,
      fileURL: sampleFileURL,
      originalText: content
    )

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 8)
    #expect(diagnostic.message.contains("U+0001"))
  }

  @Test func countsColumnsInCharacters() {
    // The family emoji is one character made of five scalars.
    let content = "家族👨\u{200D}👩\u{200D}👧\u{0001}です\u{0002}"
    let document = Document(parsing: content)
    let rule = ControlCharacterRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.column) == [4, 7])
  }

  @Test func fixRemovesControlCharacters() {
    let content = "テキスト\u{0007}と\u{0002}改行\n次の行"
    let rule = ControlCharacterRule()

    let fixed = rule.fixed(content)

    #expect(fixed == "テキストと改行\n次の行")
  }

  @Test func allowsPermittedControlCharacters() {
    let content = "タブ\tは許可\r\n改行"
    let document = Document(parsing: content)
    let rule = ControlCharacterRule()

    let diagnostics = rule.check(
      document: document,
      fileURL: sampleFileURL,
      originalText: content
    )

    #expect(diagnostics.isEmpty)
  }

  @Test func leavesFormatCharactersAlone() {
    // U+200D (zero-width joiner) glues emoji sequences together, and U+200B is
    // reported by ZeroWidthSpaceRule; neither is a Cc control character.
    let content = "家族👨\u{200D}👩\u{200D}👧です\n前\u{200B}後"
    let document = Document(parsing: content)
    let rule = ControlCharacterRule()

    let diagnostics = rule.check(
      document: document,
      fileURL: sampleFileURL,
      originalText: content
    )

    #expect(diagnostics.isEmpty)
    #expect(rule.fixed(content) == content)
  }
}
