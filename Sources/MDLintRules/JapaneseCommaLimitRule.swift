import Foundation
import Markdown
import MDLintCore

/// A rule that enforces a limit on the number of Japanese commas (、) per sentence.
///
/// Overusing commas makes Japanese sentences harder to read. This rule tracks commas
/// within a sentence and emits a diagnostic when the fourth comma is encountered,
/// encouraging the author to split or restructure the sentence.
public struct JapaneseCommaLimitRule: Rule {
    public let id = "ja.comma.max-three"
    public let description = "一文に含める読点は3つまでにしてください。"

    private let commaCharacter: Character = "、"
    private let sentenceTerminators: Set<Character> = ["。", "！", "？", "!", "?", "．"]
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

        func emitDiagnosticIfNeeded() {
            guard limitExceeded,
                  let diagnosticLine = exceedingCommaLine,
                  let diagnosticColumn = exceedingCommaColumn else {
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
            if character == commaCharacter {
                commaCount += 1
                if commaCount == maxCommaCount + 1 {
                    limitExceeded = true
                    exceedingCommaLine = line
                    exceedingCommaColumn = column
                }
            }

            if sentenceTerminators.contains(character) {
                emitDiagnosticIfNeeded()
                commaCount = 0
                limitExceeded = false
                exceedingCommaLine = nil
                exceedingCommaColumn = nil
            }

            if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        emitDiagnosticIfNeeded()

        return diagnostics
    }
}
