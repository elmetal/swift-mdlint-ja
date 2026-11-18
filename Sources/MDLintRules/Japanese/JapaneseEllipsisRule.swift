import Foundation
import MDLintCore
import Markdown

/// A rule that enforces even-length ellipsis characters in Japanese text.
///
/// Japanese typography prefers ellipses rendered as paired "…" characters.
/// This rule walks each line of Markdown source outside of code blocks and
/// inline code spans, searching for runs of odd length and recommending an
/// autofix that inserts an additional ellipsis to reach the closest even count.
public struct JapaneseEllipsisRule: Rule, AutoFixable {
  public let id = "ja.ellipsis.prefer-double"
  public let description = "3点リーダーは「……」に統一してください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let codeLines = document.codeBlockLineNumbers
    let inlineCode = document.inlineCodeRanges(in: originalText)
    let ellipsis: Character = "…"

    for (lineNumber, line) in originalText.sourceLines.enumerated()
    where !codeLines.contains(lineNumber + 1) {
      var index = line.startIndex
      while index != line.endIndex {
        if line[index] == ellipsis {
          var end = index
          var count = 0
          while end != line.endIndex, line[end] == ellipsis {
            count += 1
            end = line.index(after: end)
          }

          if count % 2 != 0, !inlineCode.contains(index) {
            let column = line.distance(from: line.startIndex, to: index) + 1
            let original = String(line[index..<end])
            let replacement = String(repeating: "…", count: count + 1)
            let diagnostic = Diagnostic(
              file: fileURL,
              line: lineNumber + 1,
              column: column,
              ruleID: id,
              message: "3点リーダーは「……」のように偶数個続けてください。",
              severity: .warning,
              fixIt: "「\(original)」を「\(replacement)」に置換"
            )
            diagnostics.append(diagnostic)
          }

          index = end
        } else {
          index = line.index(after: index)
        }
      }
    }

    return diagnostics
  }

  public func fixing(originalText: String) -> String {
    let ellipsis: Character = "…"
    let document = Document(parsing: originalText)
    let codeLines = document.codeBlockLineNumbers
    let inlineCode = document.inlineCodeRanges(in: originalText)

    return originalText.mappingSourceLines(skipping: codeLines) { line in
      var newLine = ""
      var index = line.startIndex

      while index != line.endIndex {
        if line[index] == ellipsis {
          var end = index
          var count = 0
          while end != line.endIndex, line[end] == ellipsis {
            count += 1
            end = line.index(after: end)
          }

          let isFixable = count % 2 != 0 && !inlineCode.contains(index)
          let replacementCount = isFixable ? count + 1 : count
          newLine.append(String(repeating: "…", count: replacementCount))
          index = end
        } else {
          newLine.append(line[index])
          index = line.index(after: index)
        }
      }

      return newLine
    }
  }
}
