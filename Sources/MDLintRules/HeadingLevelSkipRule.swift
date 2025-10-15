import Foundation
import Markdown
import MDLintCore

/// Rule: 見出しレベルの飛び級（例: H2 -> H4）を禁止
public struct HeadingLevelSkipRule: Rule {
    public let id = "md.heading.no-skip-level"
    public let description = "見出しレベルを1段ずつ上げてください（例: H2の次はH3）。"
    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var out: [Diagnostic] = []
        var lastLevel: Int = 0
        var lineCursor = 1

        let lines = originalText.components(separatedBy: "\n")
        for line in lines {
            if let level = headingLevel(of: line) {
                if lastLevel > 0, level > lastLevel + 1 {
                    let d = Diagnostic(file: fileURL,
                                       line: lineCursor,
                                       column: 1,
                                       ruleID: id,
                                       message: "H\(lastLevel) の次に H\(level) は飛び級です。H\(lastLevel + 1) を検討してください。",
                                       severity: .warning)
                    out.append(d)
                }
                lastLevel = level
            }
            lineCursor += 1
        }
        return out
    }

    private func headingLevel(of line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let level = trimmed.prefix(while: { $0 == "#" }).count
        return level
    }
}