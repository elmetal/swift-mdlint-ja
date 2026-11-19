import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("HalfwidthKanaRule")
struct HalfwidthKanaRuleTests {
  @Test func reportsHalfwidthKanaCharacters() throws {
    let content = "これはﾃｽﾄです"
    let document = Document(parsing: content)
    let rule = HalfwidthKanaRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 3)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 1)
    #expect(diagnostic.column == 4)
  }

  @Test func reportsKanaWithVoicedSoundMarkOnceAndCountsColumnsInCharacters() {
    // "ｸﾞ" is one character made of two scalars, and so is the family emoji.
    let content = "👨\u{200D}👩\u{200D}👧ﾛｸﾞです"
    let document = Document(parsing: content)
    let rule = HalfwidthKanaRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.column) == [2, 3])
    #expect(diagnostics.last?.message.contains("（ｸﾞ）") == true)
  }

  @Test func passesWhenOnlyFullwidthKanaIsPresent() {
    let content = "これはテストです"
    let document = Document(parsing: content)
    let rule = HalfwidthKanaRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func ignoresCodeBlocks() {
    let content = "本文\n\n```\nﾛｸﾞ出力\n```\n"
    let rule = HalfwidthKanaRule()

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func ignoresInlineCode() throws {
    let content = "ﾃ と `ｽﾄ` です"
    let rule = HalfwidthKanaRule()

    let diagnostics = rule.diagnostics(for: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.column == 1)
  }
}
