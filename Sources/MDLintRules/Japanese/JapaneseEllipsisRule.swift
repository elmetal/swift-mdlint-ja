import Foundation
import MDLintCore
import Markdown

/// A rule that enforces even-length ellipsis characters in Japanese text.
///
/// Japanese typography prefers ellipses rendered as paired "…" characters.
/// This rule walks each line of Markdown source, searching for runs of odd
/// length and attaching a fix-it that adds one more ellipsis to reach the
/// closest even count. The linter hides code and raw HTML before the
/// rule runs.
public struct JapaneseEllipsisRule: Rule {
  public let id = "ja.ellipsis.prefer-double"
  public let description = "3点リーダーは「……」に統一してください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let ellipsis: Character = "…"

    for (lineNumber, line) in originalText.sourceLines.enumerated() {
      var index = line.startIndex
      while index != line.endIndex {
        if line[index] == ellipsis {
          var end = index
          var count = 0
          while end != line.endIndex, line[end] == ellipsis {
            count += 1
            end = line.index(after: end)
          }

          if count % 2 != 0 {
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
              fixIt: FixIt(
                description: "「\(original)」を「\(replacement)」に置換",
                replacing: index..<end, in: line, lineNumber: lineNumber + 1, with: replacement)
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
}
