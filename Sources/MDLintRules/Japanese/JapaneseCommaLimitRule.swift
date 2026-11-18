import Foundation
import MDLintCore
import Markdown

/// A rule that enforces a limit on the number of Japanese commas (、) per sentence.
///
/// Overusing commas makes Japanese sentences harder to read. This rule tracks commas
/// within a sentence and emits a diagnostic when the fourth comma is encountered,
/// encouraging the author to split or restructure the sentence. A sentence ends at
/// a terminator such as "。", at a blank line (a paragraph break), or at a code
/// block; the contents of code blocks are not counted.
public struct JapaneseCommaLimitRule: Rule {
  public let id = "ja.comma.max-three"
  public let description = "一文に含める読点は3つまでにしてください。"

  private let commaCharacter: Character = "、"
  // A masked code or HTML block also ends the sentence that precedes it.
  private let sentenceTerminators: Set<Character> = [
    "。", "！", "？", "!", "?", "．", MaskedSource.blockPlaceholder,
  ]
  private let maxCommaCount = 3

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    var line = 1
    var column = 1

    var commaCount = 0
    var limitExceeded = false
    var exceedingCommaLine: Int?
    var exceedingCommaColumn: Int?
    var lineIsBlank = true
    let codeLines = document.codeBlockLineNumbers
    var inCodeBlock = codeLines.contains(line)

    func endSentence() {
      defer {
        commaCount = 0
        limitExceeded = false
        exceedingCommaLine = nil
        exceedingCommaColumn = nil
      }
      guard limitExceeded,
        let diagnosticLine = exceedingCommaLine,
        let diagnosticColumn = exceedingCommaColumn
      else {
        return
      }

      let message = "一文に読点が4つ以上あります（読点の数: \(commaCount)）。文を分割するなどして読みやすさを見直してください。"
      let diagnostic = Diagnostic(
        file: fileURL,
        line: diagnosticLine,
        column: diagnosticColumn,
        ruleID: id,
        message: message,
        severity: .warning,
        fixIt: nil
      )
      diagnostics.append(diagnostic)
    }

    for character in originalText {
      if inCodeBlock {
        if character.isLineTerminator {
          line += 1
          column = 1
          inCodeBlock = codeLines.contains(line)
        }
        continue
      }

      if character == commaCharacter {
        commaCount += 1
        if commaCount == maxCommaCount + 1 {
          limitExceeded = true
          exceedingCommaLine = line
          exceedingCommaColumn = column
        }
      }

      if sentenceTerminators.contains(character) {
        endSentence()
      }

      if character.isLineTerminator {
        // A blank line separates paragraphs, so no sentence continues across it.
        if lineIsBlank { endSentence() }
        line += 1
        column = 1
        lineIsBlank = true
        inCodeBlock = codeLines.contains(line)
        // A code block interrupts the paragraph it follows.
        if inCodeBlock { endSentence() }
      } else {
        column += 1
        if !character.isWhitespace { lineIsBlank = false }
      }
    }

    endSentence()

    return diagnostics
  }
}
