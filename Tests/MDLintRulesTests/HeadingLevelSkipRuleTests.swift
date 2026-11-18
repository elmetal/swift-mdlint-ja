import Foundation
import Markdown
import Testing

@testable import MDLintRules

@Suite("HeadingLevelSkipRule")
struct HeadingLevelSkipRuleTests {
  @Test func reportsSkippedHeadingLevels() throws {
    let content = "# タイトル\n## セクション\n#### 飛び級"
    let document = Document(parsing: content)
    let rule = HeadingLevelSkipRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.count == 1)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.ruleID == rule.id)
    #expect(diagnostic.line == 3)
  }

  @Test func allowsSequentialHeadingLevels() {
    let content = "# タイトル\n## セクション\n### サブセクション"
    let document = Document(parsing: content)
    let rule = HeadingLevelSkipRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func ignoresHashLinesThatAreNotHeadings() {
    // A shell comment inside a code block and a hashtag are not headings, so
    // H2 → H3 below is sequential.
    let content = "# タイトル\n\n## 使い方\n\n```bash\n# install\n```\n\n#hashtag\n\n### 詳細"
    let document = Document(parsing: content)
    let rule = HeadingLevelSkipRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    #expect(diagnostics.isEmpty)
  }

  @Test func recognizesSetextHeadings() throws {
    let content = "タイトル\n===\n\n### 飛び級"
    let document = Document(parsing: content)
    let rule = HeadingLevelSkipRule()

    let diagnostics = rule.check(document: document, fileURL: sampleFileURL, originalText: content)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostics.count == 1)
    #expect(diagnostic.line == 4)
    #expect(diagnostic.column == 1)
  }
}
