import Markdown
import Testing

@testable import MDLintRules

@Suite("CodeBlockLines")
struct CodeBlockLinesTests {
  @Test func includesFencesOfFencedCodeBlocks() {
    let document = Document(parsing: "本文\n\n```swift\nlet x = 1\n```\n\n本文")

    #expect(document.codeBlockLineNumbers == [3, 4, 5])
  }

  @Test func includesIndentedCodeBlocks() {
    let document = Document(parsing: "本文\n\n    indented 1\n    indented 2\n本文")

    #expect(document.codeBlockLineNumbers == [3, 4])
  }

  @Test func includesCodeBlocksNestedInListsAndBlockQuotes() {
    let document = Document(
      parsing: "- item\n\n  ```\n  code\n  ```\n\n> ~~~\n> quoted\n> ~~~\n\n本文")

    #expect(document.codeBlockLineNumbers == [3, 4, 5, 7, 8, 9])
  }

  @Test func extendsUnclosedFenceToTheEndOfTheDocument() {
    let document = Document(parsing: "本文\n\n```\nunclosed\nmore")

    #expect(document.codeBlockLineNumbers == [3, 4, 5])
  }

  @Test func isEmptyWithoutCodeBlocks() {
    let document = Document(parsing: "# 見出し\n\n`inline` は対象外")

    #expect(document.codeBlockLineNumbers.isEmpty)
  }
}
