import Foundation
import Markdown
import MDLintCore

/// Rule: 終止符は「。」に統一する（段落テキスト内の文末の「.」や「．」を検出）
public struct JapanesePeriodRule: Rule, AutoFixable {
    public let id = "ja.period.prefer-fullwidth"
    public let description = "文末の終止符は「。」に統一してください。"

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var out: [Diagnostic] = []
        let text = originalText

        // 単純化: 行単位で見る。末尾の "." または "．" を検出（コードブロックは除外したいが最小構成のため簡略化）
        let lines = text.components(separatedBy: "\n")
        var offset = 0
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(".") || trimmed.hasSuffix("．") {
                let column = line.count
                let d = Diagnostic(file: fileURL,
                                   line: i + 1,
                                   column: column,
                                   ruleID: id,
                                   message: "文末は「。」に統一しましょう（現在: \(trimmed.suffix(1))）。",
                                   severity: .warning,
                                   fixIt: "末尾の \(trimmed.suffix(1)) を「。」に置換")
                out.append(d)
            }
            offset += line.utf16.count + 1
        }
        return out
    }

    public func fixing(originalText: String) -> String {
        var lines = originalText.components(separatedBy: "\n")
        for i in lines.indices {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).hasSuffix(".") ||
               line.trimmingCharacters(in: .whitespaces).hasSuffix("．") {
                // 行末の "."/ "．" を "。" に
                // 末尾の空白を保持しつつ置換
                let rtrimmed = line.rstripSpaces()
                if rtrimmed.hasSuffix(".") || rtrimmed.hasSuffix("．") {
                    let dropCount = 1
                    let new = String(rtrimmed.dropLast(dropCount)) + "。"
                    let suffixSpaces = String(line.dropFirst(rtrimmed.count))
                    lines[i] = new + suffixSpaces
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

private extension String {
    func rstripSpaces() -> String {
        var s = self
        while s.last == " " || s.last == "\t" {
            s.removeLast()
        }
        return s
    }
}