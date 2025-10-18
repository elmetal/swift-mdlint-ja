import Foundation
import Markdown
import MDLintCore

/// A rule that removes superfluous spaces between Japanese and Latin text.
///
/// Full-width Japanese characters and adjacent ASCII words should appear
/// without separating spaces. The rule searches each line for whitespace that
/// divides Japanese and English segments and produces diagnostics with autofix
/// replacements that collapse the gap.
public struct JapaneseEnglishSpacingRule: Rule, AutoFixable {
    public let id = "ja.spacing.no-space-between-japanese-and-english"
    public let description = "和文と英単語の間にスペースは入れないでください。"

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let lines = originalText.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            diagnostics.append(contentsOf: diagnosticsForLine(line, lineNumber: index + 1, fileURL: fileURL))
        }

        return diagnostics
    }

    public func fixing(originalText: String) -> String {
        originalText
            .replacing(Self.japaneseBeforeEnglishRegex) { match in
                "\(match.output.1)\(match.output.3)"
            }
            .replacing(Self.englishBeforeJapaneseRegex) { match in
                "\(match.output.1)\(match.output.3)"
            }
    }

    private func diagnosticsForLine(_ line: String, lineNumber: Int, fileURL: URL) -> [Diagnostic] {
        var result: [Diagnostic] = []

        for match in line.matches(of: Self.japaneseBeforeEnglishRegex) {
            let column = line.distance(from: line.startIndex, to: match.output.2.startIndex) + 1
            let diagnostic = Diagnostic(file: fileURL,
                                        line: lineNumber,
                                        column: column,
                                        ruleID: id,
                                        message: "和文と英単語の間にスペースは入れないでください。",
                                        severity: .warning,
                                        fixIt: "スペースを削除")
            result.append(diagnostic)
        }

        for match in line.matches(of: Self.englishBeforeJapaneseRegex) {
            let column = line.distance(from: line.startIndex, to: match.output.2.startIndex) + 1
            let diagnostic = Diagnostic(file: fileURL,
                                        line: lineNumber,
                                        column: column,
                                        ruleID: id,
                                        message: "和文と英単語の間にスペースは入れないでください。",
                                        severity: .warning,
                                        fixIt: "スペースを削除")
            result.append(diagnostic)
        }

        return result
    }

    private static let japaneseBeforeEnglishRegex = try! Regex<(
        Substring,
        Substring,
        Substring,
        Substring
    )>(#"([\p{Han}\p{Hiragana}\p{Katakana}々〆ヵヶ])([ \t]+)([A-Za-z])"#)

    private static let englishBeforeJapaneseRegex = try! Regex<(
        Substring,
        Substring,
        Substring,
        Substring
    )>(#"([A-Za-z])([ \t]+)([\p{Han}\p{Hiragana}\p{Katakana}々〆ヵヶ])"#)
}
