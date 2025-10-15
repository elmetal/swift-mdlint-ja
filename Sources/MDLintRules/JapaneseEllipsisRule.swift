import Foundation
import Markdown
import MDLintCore

/// Rule: 3点リーダーは「……」に統一する（奇数個の連続した「…」を検出）
public struct JapaneseEllipsisRule: Rule, AutoFixable {
    public let id = "ja.ellipsis.prefer-double"
    public let description = "3点リーダーは「……」に統一してください。"

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let lines = originalText.components(separatedBy: "\n")
        let ellipsis: Character = "…"

        for (lineNumber, line) in lines.enumerated() {
            var index = line.startIndex
            while index != line.endIndex {
                if line[index] == ellipsis {
                    var end = index
                    var count = 0
                    while end != line.endIndex, line[end] == ellipsis {
                        count += 1
                        end = line.index(after: end)
                    }

                    if count % 2 != 0 {
                        let column = line.distance(from: line.startIndex, to: index) + 1
                        let original = String(line[index..<end])
                        let replacement = String(repeating: "…", count: count + 1)
                        let diagnostic = Diagnostic(
                            file: fileURL,
                            line: lineNumber + 1,
                            column: column,
                            ruleID: id,
                            message: "3点リーダーは「……」のように偶数個続けてください。",
                            severity: .warning,
                            fixIt: "「\(original)」を「\(replacement)」に置換"
                        )
                        diagnostics.append(diagnostic)
                    }

                    index = end
                } else {
                    index = line.index(after: index)
                }
            }
        }

        return diagnostics
    }

    public func fixing(originalText: String) -> String {
        let ellipsis: Character = "…"
        var lines = originalText.components(separatedBy: "\n")

        for lineIndex in lines.indices {
            let line = lines[lineIndex]
            var newLine = ""
            var index = line.startIndex

            while index != line.endIndex {
                if line[index] == ellipsis {
                    var end = index
                    var count = 0
                    while end != line.endIndex, line[end] == ellipsis {
                        count += 1
                        end = line.index(after: end)
                    }

                    let replacementCount = count % 2 == 0 ? count : count + 1
                    newLine.append(String(repeating: "…", count: replacementCount))
                    index = end
                } else {
                    newLine.append(line[index])
                    index = line.index(after: index)
                }
            }

            lines[lineIndex] = newLine
        }

        return lines.joined(separator: "\n")
    }
}
