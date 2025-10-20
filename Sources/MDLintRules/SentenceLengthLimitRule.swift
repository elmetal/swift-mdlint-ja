import Foundation
import Markdown
import MDLintCore

/// A rule that enforces a maximum sentence length of 100 characters, excluding URLs.
///
/// Long sentences can reduce readability. This rule counts characters in each sentence
/// while ignoring URL substrings and reports a diagnostic when the length exceeds 100.
public struct SentenceLengthLimitRule: Rule {
    public let id = "ja.sentence.max-one-hundred-characters"
    public let description = "URL を除いて一文は100文字以内にしてください。"

    private let sentenceTerminators: Set<Character> = ["。", "！", "？", "!", "?", "．"]
    private let maxLength = 100

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(
            in: originalText,
            options: [],
            range: NSRange(location: 0, length: (originalText as NSString).length)
        ) ?? []
        let urlRanges = matches.compactMap { Range($0.range, in: originalText) }

        var currentURLRangeIndex = 0

        var diagnostics: [Diagnostic] = []

        var line = 1
        var column = 1

        var currentLength = 0
        var exceeded = false
        var exceedingLine: Int?
        var exceedingColumn: Int?

        func emitDiagnosticIfNeeded(currentSentenceLength: Int) {
            guard exceeded,
                  let diagnosticLine = exceedingLine,
                  let diagnosticColumn = exceedingColumn else {
                return
            }

            let message = "一文が101文字以上になっています（現在の文字数: \(currentSentenceLength)）。URL を除いて100文字以内に収まるように文を見直してください。"
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

        var index = originalText.startIndex
        while index < originalText.endIndex {
            let character = originalText[index]
            let nextIndex = originalText.index(after: index)

            while currentURLRangeIndex < urlRanges.count && index >= urlRanges[currentURLRangeIndex].upperBound {
                currentURLRangeIndex += 1
            }

            let isInURL: Bool
            if currentURLRangeIndex < urlRanges.count {
                let range = urlRanges[currentURLRangeIndex]
                isInURL = index >= range.lowerBound && index < range.upperBound
            } else {
                isInURL = false
            }

            if !isInURL {
                currentLength += 1
                if currentLength == maxLength + 1 {
                    exceeded = true
                    exceedingLine = line
                    exceedingColumn = column
                }
            }

            if sentenceTerminators.contains(character) {
                emitDiagnosticIfNeeded(currentSentenceLength: currentLength)
                currentLength = 0
                exceeded = false
                exceedingLine = nil
                exceedingColumn = nil
            }

            if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }

            index = nextIndex
        }

        emitDiagnosticIfNeeded(currentSentenceLength: currentLength)

        return diagnostics
    }
}
