import Foundation
import Markdown
import MDLintCore

/// Rule: インラインコードのバッククォートが閉じられているか検出する
public struct InlineBacktickClosureRule: Rule {
    public let id = "ja.backtick.unmatched"
    public let description = "インラインコードのバッククォートは閉じてください。"

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let lines = originalText.components(separatedBy: "\n")
        var inFencedCodeBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFencedCodeBlock.toggle()
                continue
            }

            if inFencedCodeBlock { continue }

            var isInsideInlineCode = false
            var unmatchedColumn: Int?
            var currentIndex = line.startIndex

            while currentIndex < line.endIndex {
                if line[currentIndex] == "`" {
                    var runLength = 0
                    var lookahead = currentIndex
                    while lookahead < line.endIndex && line[lookahead] == "`" {
                        runLength += 1
                        lookahead = line.index(after: lookahead)
                    }

                    for _ in 0..<runLength {
                        if isInsideInlineCode {
                            isInsideInlineCode = false
                            unmatchedColumn = nil
                        } else {
                            isInsideInlineCode = true
                            if unmatchedColumn == nil {
                                let column = line.distance(from: line.startIndex, to: currentIndex) + 1
                                unmatchedColumn = column
                            }
                        }
                    }

                    currentIndex = lookahead
                    continue
                }

                currentIndex = line.index(after: currentIndex)
            }

            if isInsideInlineCode, let column = unmatchedColumn {
                let diagnostic = Diagnostic(
                    file: fileURL,
                    line: index + 1,
                    column: column,
                    ruleID: id,
                    message: "インラインコードのバッククォートが閉じられていません。"
                )
                diagnostics.append(diagnostic)
            }
        }

        return diagnostics
    }
}
