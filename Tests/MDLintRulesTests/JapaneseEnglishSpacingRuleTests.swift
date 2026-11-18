import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("JapaneseEnglishSpacingRule")
struct JapaneseEnglishSpacingRuleTests {
  @Test func reportsSpacesBetweenJapaneseAndEnglishWords() {
    let content = "これは Test です"
    let document = Document(parsing: content)
    let rule = JapaneseEnglishSpacingRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 2)
    #expect(diagnostics.allSatisfy { $0.ruleID == rule.id })
  }

  @Test func fixRemovesSpacesBetweenJapaneseAndEnglishWords() {
    let content = "これは Test です\nSwift を 使う"
    let rule = JapaneseEnglishSpacingRule()

    let fixed = rule.fixing(originalText: content)

    #expect(fixed == "これはTestです\nSwiftを 使う")
  }

  @Test func doesNotReportSpacesBetweenJapaneseWords() {
    let content = "和 文 の 間"
    let document = Document(parsing: content)
    let rule = JapaneseEnglishSpacingRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func fixDoesNotRemoveSpacesBetweenJapaneseWords() {
    let content = "和 文 の 間"
    let rule = JapaneseEnglishSpacingRule()

    let fixed = rule.fixing(originalText: content)

    #expect(fixed == content)
  }

  @Test func leavesCodeBlocksAlone() {
    let content = "これは Test です\n\n```bash\necho \"これは Test です\"\n```\n"
    let document = Document(parsing: content)
    let rule = JapaneseEnglishSpacingRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.map(\.line) == [1, 1])
    #expect(
      rule.fixing(originalText: content)
        == "これはTestです\n\n```bash\necho \"これは Test です\"\n```\n")
  }

  @Test func fixKeepsWindowsLineEndings() {
    let content = "これは Test です\r\nSwift を使う\r\n"
    let rule = JapaneseEnglishSpacingRule()

    #expect(rule.fixing(originalText: content) == "これはTestです\r\nSwiftを使う\r\n")
  }
}
