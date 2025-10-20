import Foundation
import Markdown
import MDLintCore

/// A rule that flags the presence of disallowed control characters.
///
/// Control characters such as NULL or BELL often end up in Markdown files as
/// invisible copy-and-paste artifacts. Because they do not render in the
/// output and may cause issues in downstream tooling, this rule reports each
/// occurrence and offers to remove them.
public struct ControlCharacterRule: Rule, AutoFixable {
    public let id = "md.characters.no-control"
    public let description = "制御文字を含めないでください。"

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let lines = originalText.components(separatedBy: "\n")

        for (lineIndex, line) in lines.enumerated() {
            for (columnOffset, scalar) in line.unicodeScalars.enumerated() where CharacterSet.disallowedControl.contains(scalar) {
                let column = columnOffset + 1
                let codePoint = String(format: "U+%04X", scalar.value)
                let diagnostic = Diagnostic(
                    file: fileURL,
                    line: lineIndex + 1,
                    column: column,
                    ruleID: id,
                    message: "制御文字 (\(codePoint)) を削除してください。",
                    severity: .warning,
                    fixIt: "制御文字を削除"
                )
                diagnostics.append(diagnostic)
            }
        }

        return diagnostics
    }

    public func fixing(originalText: String) -> String {
        originalText.components(separatedBy: .disallowedControl).joined()
    }
}

extension CharacterSet {
    static let disallowedControl: Self = {
        var set = CharacterSet.controlCharacters
        set.remove(charactersIn: "\n\r\t")
        return set
    }()
}
