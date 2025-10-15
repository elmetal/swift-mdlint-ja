import Foundation
import Markdown
import MDLintCore

/// Rule: 見出しの文末に句読点を付けない（「。」「.」「．」「、」など）
public struct HeadingTerminalPunctuationRule: Rule, AutoFixable {
    public let id = "ja.heading.no-terminal-punctuation"
    public let description = "見出し（# ...）の末尾に句読点は付けないでください。"

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var out: [Diagnostic] = []
        let src = originalText as NSString

        for (idx, block) in document.blockChildren.enumerated() {
            guard let heading = block as? Heading else { continue }
            let text = heading.plainText
            guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else { continue }
            if ["。", "．", ".", "、", ","].contains(String(last)) {
                // ラフに位置特定: heading の最初の行番号を推定
                let search = "#"
                // 近似: ドキュメント先頭から heading のテキストを探す（最初の一致）
                if let range = src.range(of: text, options: [], range: NSRange(location: 0, length: src.length)) as NSRange? {
                    let (line, col) = lineColumn(in: originalText, utf16Offset: range.location + range.length)
                    let d = Diagnostic(file: fileURL,
                                       line: line,
                                       column: col,
                                       ruleID: id,
                                       message: "見出し末尾の句読点「\(last)」を削除してください。",
                                       severity: .warning,
                                       fixIt: "末尾の句読点を除去")
                    out.append(d)
                }
            }
        }
        return out
    }

    public func fixing(originalText: String) -> String {
        let lines = originalText.components(separatedBy: "\n")
        var newLines: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                var trimmedRight = line.rstripSpaces()
                let forbidden = ["。", "．", ".", "、", ","]
                if let last = trimmedRight.last, forbidden.contains(String(last)) {
                    trimmedRight.removeLast()
                    newLines.append(trimmedRight)
                    continue
                }
            }
            newLines.append(line)
        }
        return newLines.joined(separator: "\n")
    }
}

private func lineColumn(in text: String, utf16Offset: Int) -> (Int, Int) {
    var line = 1, col = 1, count = 0
    for ch in text {
        if count >= utf16Offset { break }
        if ch == "\n" { line += 1; col = 1 } else { col += 1 }
        count += String(ch).utf16.count
    }
    return (line, col)
}

private extension String {
    func rstripSpaces() -> String {
        var s = self
        while s.last == " " || s.last == "\t" { s.removeLast() }
        return s
    }
}

private extension Heading {
    var plainText: String {
        self.plainTextInlines()
    }
    func plainTextInlines() -> String {
        self.children.compactMap { inline -> String? in
            if let text = inline as? Text { return text.string }
            if let code = inline as? InlineCode { return code.code }
            if let strong = inline as? Strong { return strong.children.compactMap { ($0 as? Text)?.string }.joined() }
            if let em = inline as? Emphasis { return em.children.compactMap { ($0 as? Text)?.string }.joined() }
            return nil
        }.joined()
    }
}