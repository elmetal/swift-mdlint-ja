import Foundation
import MDLintCore
import Markdown

/// A rule that flags zero-width space characters in Markdown documents.
///
/// The zero-width space (U+200B) is invisible and is usually introduced by
/// mistake during copy-and-paste operations. Because it is hard to notice in
/// rendered documents, this rule surfaces diagnostics for each occurrence and
/// suggests removing the character.
public struct ZeroWidthSpaceRule: Rule, AutoFixable {
  public let id = "md.whitespace.no-zero-width-space"
  public let description = "ゼロ幅スペースを含めないでください。"

  private static let zeroWidthSpace: Unicode.Scalar = "\u{200B}"

  public init() {}

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    for (lineIndex, line) in originalText.sourceLines.enumerated() {
      // Columns count characters, as in every other rule, not Unicode scalars.
      for (columnOffset, character) in line.enumerated() {
        for scalar in character.unicodeScalars where scalar == Self.zeroWidthSpace {
          let diagnostic = Diagnostic(
            file: fileURL,
            line: lineIndex + 1,
            column: columnOffset + 1,
            ruleID: id,
            message: "ゼロ幅スペース (U+200B) を削除してください。",
            severity: .warning,
            fixIt: "ゼロ幅スペースを削除"
          )
          diagnostics.append(diagnostic)
        }
      }
    }

    return diagnostics
  }

  public func fixing(originalText: String) -> String {
    originalText.replacingOccurrences(of: String(Self.zeroWidthSpace), with: "")
  }
}
