
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
        let mutable = NSMutableString(string: originalText)
        Self.removeSpacesMatched(by: Self.japaneseBeforeEnglishRegex, in: mutable)
        Self.removeSpacesMatched(by: Self.englishBeforeJapaneseRegex, in: mutable)
        return mutable as String
    }

    private func diagnosticsForLine(_ line: String, lineNumber: Int, fileURL: URL) -> [Diagnostic] {
        var result: [Diagnostic] = []
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        Self.japaneseBeforeEnglishRegex.enumerateMatches(in: line, options: [], range: fullRange) { match, _, _ in
            guard let match = match, let spaceRange = Range(match.range(at: 2), in: line) else { return }
            let column = line.distance(from: line.startIndex, to: spaceRange.lowerBound) + 1
            let diagnostic = Diagnostic(file: fileURL,
                                        line: lineNumber,
                                        column: column,
                                        ruleID: id,
                                        message: "和文と英単語の間にスペースは入れないでください。",
                                        severity: .warning,
                                        fixIt: "スペースを削除")
            result.append(diagnostic)
        }

        Self.englishBeforeJapaneseRegex.enumerateMatches(in: line, options: [], range: fullRange) { match, _, _ in
            guard let match = match, let spaceRange = Range(match.range(at: 2), in: line) else { return }
            let column = line.distance(from: line.startIndex, to: spaceRange.lowerBound) + 1
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

    private static let japaneseBeforeEnglishRegex = try! NSRegularExpression(pattern: "([\\p{Han}\\p{Hiragana}\\p{Katakana}々〆ヵヶ])([ \\t]+)([A-Za-z])")
    private static let englishBeforeJapaneseRegex = try! NSRegularExpression(pattern: "([A-Za-z])([ \\t]+)([\\p{Han}\\p{Hiragana}\\p{Katakana}々〆ヵヶ])")

    private static func removeSpacesMatched(by regex: NSRegularExpression, in text: NSMutableString) {
        let string = text as String
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: text.length))
        for match in matches.reversed() {
            let left = text.substring(with: match.range(at: 1))
            let right = text.substring(with: match.range(at: 3))
            text.replaceCharacters(in: match.range, with: "\(left)\(right)")
        }
    }
}
