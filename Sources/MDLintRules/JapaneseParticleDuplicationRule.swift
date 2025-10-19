import Foundation
import Markdown
import MDLintCore

/// A rule that detects back-to-back Japanese particles that are likely accidental duplicates.
///
/// Many typographical mistakes stem from repeating the same particle (for example "にに" or
/// "をを") when editing text. This rule scans the original Markdown source line by line and
/// raises a diagnostic whenever it finds the same particle repeated consecutively, ignoring
/// whitespace between the repetitions.
public struct JapaneseParticleDuplicationRule: Rule {
    public let id = "ja.particle.no-duplicate"
    public let description = "同じ助詞が続く重複を避けてください。"

    private let particles: [String] = [
        "は", "が", "に", "を", "と", "で", "へ", "から", "まで", "より"
    ]

    public init() {}

    public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let lines = originalText.components(separatedBy: "\n")

        for (lineNumber, line) in lines.enumerated() {
            diagnostics.append(contentsOf: diagnosticsForLine(line,
                                                              lineNumber: lineNumber + 1,
                                                              fileURL: fileURL))
        }

        return diagnostics
    }

    private func diagnosticsForLine(_ line: String, lineNumber: Int, fileURL: URL) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        for particle in particles {
            var searchRange = line.startIndex..<line.endIndex

            while let foundRange = line.range(of: particle, options: [], range: searchRange) {
                let nextStart = skipSpaces(in: line, from: foundRange.upperBound)

                if nextStart < line.endIndex, line[nextStart...].hasPrefix(particle) {
                    let column = line.distance(from: line.startIndex, to: foundRange.lowerBound) + 1
                    let diagnostic = Diagnostic(
                        file: fileURL,
                        line: lineNumber,
                        column: column,
                        ruleID: id,
                        message: "助詞「\(particle)」が連続しています。不要な繰り返しを確認してください。",
                        severity: .warning,
                        fixIt: nil
                    )
                    diagnostics.append(diagnostic)
                }

                if nextStart < line.endIndex {
                    searchRange = nextStart..<line.endIndex
                } else {
                    break
                }
            }
        }

        return diagnostics
    }

    private func skipSpaces(in line: String, from index: String.Index) -> String.Index {
        var current = index
        while current < line.endIndex {
            let character = line[current]
            if character.isParticleSpace {
                current = line.index(after: current)
            } else {
                break
            }
        }
        return current
    }
}

private extension Character {
    var isParticleSpace: Bool {
        return unicodeScalars.allSatisfy { Character.particleSpaces.contains($0) }
    }

    private static let particleSpaces = CharacterSet(charactersIn: " \t\u{3000}")
}
