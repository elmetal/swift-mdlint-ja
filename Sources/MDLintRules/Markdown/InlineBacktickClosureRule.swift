import Foundation
import MDLintCore
import Markdown

/// A rule that ensures inline code spans use balanced backticks.
///
/// Inline code snippets must open and close with the same number of backtick
/// characters. This rule inspects each non-code-block line for backtick runs
/// and reports a diagnostic when a run has no closing run of the same length
/// on that line.
public struct InlineBacktickClosureRule: Rule {
  public let id = "ja.backtick.unmatched"
  public let description = "インラインコードのバッククォートは閉じてください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    var inFencedCodeBlock = false

    for (index, line) in originalText.sourceLines.enumerated() {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("```") {
        inFencedCodeBlock.toggle()
        continue
      }

      if inFencedCodeBlock { continue }

      if let unmatched = Self.firstUnmatchedBacktickRun(in: line) {
        let diagnostic = Diagnostic(
          file: fileURL,
          line: index + 1,
          column: line.distance(from: line.startIndex, to: unmatched) + 1,
          ruleID: id,
          message: "インラインコードのバッククォートが閉じられていません。"
        )
        diagnostics.append(diagnostic)
      }
    }

    return diagnostics
  }

  /// Returns the start of the first backtick run that is not closed on the line.
  ///
  /// Following CommonMark, a run of N backticks opens a code span that is closed
  /// by the next run of exactly N backticks, and a backslash escapes a backtick
  /// outside of code spans.
  private static func firstUnmatchedBacktickRun(in line: Substring) -> String.Index? {
    var current = line.startIndex

    while current < line.endIndex {
      if line[current] == "\\" {
        // Skip the escaped character, whatever it is.
        current = line.index(after: current)
        if current < line.endIndex { current = line.index(after: current) }
        continue
      }

      guard line[current] == "`" else {
        current = line.index(after: current)
        continue
      }

      let opener = backtickRun(in: line, from: current)
      var search = opener.upperBound
      var closer: Range<String.Index>?
      while let next = line[search...].firstIndex(of: "`") {
        let run = backtickRun(in: line, from: next)
        if line.distance(from: run.lowerBound, to: run.upperBound)
          == line.distance(from: opener.lowerBound, to: opener.upperBound)
        {
          closer = run
          break
        }
        search = run.upperBound
      }

      guard let closer else { return opener.lowerBound }
      current = closer.upperBound
    }

    return nil
  }

  private static func backtickRun(in line: Substring, from start: String.Index)
    -> Range<String.Index>
  {
    var end = start
    while end < line.endIndex, line[end] == "`" {
      end = line.index(after: end)
    }
    return start..<end
  }
}
