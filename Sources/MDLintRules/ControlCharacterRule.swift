import Foundation
import MDLintCore
import Markdown

/// A rule that flags the presence of disallowed control characters.
///
/// Control characters such as NULL or BELL often end up in Markdown files as
/// invisible copy-and-paste artifacts. Because they do not render in the
/// output and may cause issues in downstream tooling, this rule reports each
/// occurrence and offers to remove them.
///
/// Only the Unicode general category `Cc` is targeted (tab and line
/// terminators excepted). Format characters (`Cf`) such as the zero-width
/// joiner are left alone because emoji sequences depend on them.
public struct ControlCharacterRule: Rule {
  public let id = "md.characters.no-control"
  public let description = "制御文字を含めないでください。"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    for (lineIndex, line) in originalText.sourceLines.enumerated() {
      // Columns count characters, as in every other rule, not Unicode scalars.
      for (columnOffset, index) in line.indices.enumerated() {
        let character = line[index]
        for scalar in character.unicodeScalars where Self.isDisallowedControl(scalar) {
          let codePoint = String(format: "U+%04X", scalar.value)
          // The fix keeps whatever else the character consists of.
          var kept = String.UnicodeScalarView()
          kept.append(
            contentsOf: character.unicodeScalars.lazy.filter { !Self.isDisallowedControl($0) })
          let diagnostic = Diagnostic(
            file: fileURL,
            line: lineIndex + 1,
            column: columnOffset + 1,
            ruleID: id,
            message: "制御文字 (\(codePoint)) を削除してください。",
            severity: .warning,
            fixIt: FixIt(
              description: "制御文字を削除",
              replacing: index..<line.index(after: index), in: line, lineNumber: lineIndex + 1,
              with: String(kept))
          )
          diagnostics.append(diagnostic)
        }
      }
    }

    return diagnostics
  }

  private static func isDisallowedControl(_ scalar: Unicode.Scalar) -> Bool {
    scalar.properties.generalCategory == .control
      && scalar != "\n" && scalar != "\r" && scalar != "\t"
  }
}
