import Foundation
import MDLintCore
import Markdown

/// A rule that prevents Markdown headings from skipping levels.
///
/// Markdown documents should promote heading levels sequentially so that an
/// `H2` heading is followed by `H3`, not `H4`. The rule tracks the level of each
/// top-level heading in the parsed document and emits a diagnostic whenever a
/// heading jumps more than one level. Because it relies on the parsed document,
/// lines that merely start with `#` (for example comments inside code blocks)
/// are not mistaken for headings.
public struct HeadingLevelSkipRule: Rule {
  public let id = "md.heading.no-skip-level"
  public let description = "見出しレベルを1段ずつ上げてください（例: H2の次はH3）。"
  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var out: [Diagnostic] = []
    var lastLevel = 0

    for block in document.children {
      guard let heading = block as? Heading else { continue }
      let level = heading.level
      if lastLevel > 0, level > lastLevel + 1, let start = heading.range?.lowerBound {
        let d = Diagnostic(
          file: fileURL,
          line: start.line,
          column: start.column,
          ruleID: id,
          message: "H\(lastLevel) の次に H\(level) は飛び級です。H\(lastLevel + 1) を検討してください。",
          severity: .warning)
        out.append(d)
      }
      lastLevel = level
    }
    return out
  }
}
