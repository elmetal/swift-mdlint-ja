import Foundation
import Markdown
import Testing
@testable import MDLintCore

private let sampleFileURL = URL(fileURLWithPath: "/tmp/sample.md")

@Suite("Linter")
struct LinterTests {
    @Test func collectsDiagnosticsWithoutApplyingFixes() throws {
        let rule = ReplaceBadRule()
        let linter = Linter(rules: [rule])
        let content = "Introduction\nbad value"

        let (diagnostics, fixed) = linter.lint(content: content, fileURL: sampleFileURL, applyFixes: false)

        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.line == 2)
        #expect(diagnostic.column == 1)
        #expect(diagnostic.ruleID == rule.id)
        #expect(diagnostic.message == "Replace 'bad' with 'good'")
        #expect(fixed == nil)
    }

    @Test func appliesFixesWhenRequested() throws {
        let rule = ReplaceBadRule()
        let linter = Linter(rules: [rule])
        let content = "bad value"

        let (diagnostics, fixed) = linter.lint(content: content, fileURL: sampleFileURL, applyFixes: true)

        #expect(diagnostics.count == 1)
        #expect(fixed == "good value")
    }
}

@Suite("Diagnostic Formatters")
struct DiagnosticFormatterTests {
    @Test func textFormatterProducesReadableOutput() {
        let diagnostic = Diagnostic(
            file: sampleFileURL,
            line: 2,
            column: 3,
            ruleID: "example.rule",
            message: "Example message",
            severity: .error
        )

        let formatter = TextDiagnosticFormatStyle()
        let formatted = formatter.format(diagnostic)

        #expect(formatted == "[ERROR] \(sampleFileURL.path):2:3 [example.rule] Example message")
    }

    @Test func ghaFormatterEscapesNewlinesAndIncludesFixIt() {
        let diagnostic = Diagnostic(
            file: sampleFileURL,
            line: 5,
            column: 2,
            ruleID: "example.rule",
            message: "First line\nSecond line",
            severity: .warning,
            fixIt: "Do something"
        )

        let formatter = GHADiagnosticFormatStyle()
        let formatted = formatter.format(diagnostic)

        #expect(formatted == "::warning file=\(sampleFileURL.path),line=5,col=2::First line%0ASecond line (fix: Do something)")
    }
}

@Suite("Diagnostic Sorting")
struct DiagnosticSortingTests {
    @Test func sortsByFileLineColumnAndRule() {
        let base = URL(fileURLWithPath: "/tmp")
        let diagA1 = Diagnostic(file: base.appendingPathComponent("a.md"), line: 1, column: 2, ruleID: "b", message: "")
        let diagA2 = Diagnostic(file: base.appendingPathComponent("a.md"), line: 1, column: 2, ruleID: "a", message: "")
        let diagB = Diagnostic(file: base.appendingPathComponent("b.md"), line: 1, column: 1, ruleID: "a", message: "")
        let diagEarlierLine = Diagnostic(file: base.appendingPathComponent("a.md"), line: 0, column: 5, ruleID: "z", message: "")
        let diagLaterColumn = Diagnostic(file: base.appendingPathComponent("a.md"), line: 1, column: 3, ruleID: "a", message: "")

        let sorted = [diagA1, diagA2, diagB, diagEarlierLine, diagLaterColumn].sorted(by: Diagnostic.sorter)

        #expect(sorted == [diagEarlierLine, diagA2, diagA1, diagLaterColumn, diagB])
    }
}

@Suite("String lineColumn")
struct LineColumnTests {
    @Test func returnsStartPositionForOffsetZero() {
        let text = "Line"
        let position = text.lineColumn(for: 0)

        #expect(position.line == 1)
        #expect(position.column == 1)
    }

    @Test func countsNewlinesAndUTF16CodeUnits() throws {
        let text = "First line\n😀A"
        let indexOfA = try #require(text.firstIndex(of: "A"))
        let utf16Index = try #require(indexOfA.samePosition(in: text.utf16))
        let offset = text.utf16.distance(from: text.utf16.startIndex, to: utf16Index)

        let position = text.lineColumn(for: offset)

        #expect(position.line == 2)
        #expect(position.column == 2)
    }
}

private struct ReplaceBadRule: Rule {
    let id = "test.replace-bad"
    let description = "Replaces the word 'bad' with 'good'"
    let isFixable = true

    func check(document _: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
        guard let range = originalText.range(of: "bad") else { return [] }
        let utf16 = originalText.utf16
        guard let utf16Start = range.lowerBound.samePosition(in: utf16) else { return [] }
        let offset = utf16.distance(from: utf16.startIndex, to: utf16Start)
        let position = originalText.lineColumn(for: offset)

        return [
            Diagnostic(
                file: fileURL,
                line: position.line,
                column: position.column,
                ruleID: id,
                message: "Replace 'bad' with 'good'"
            )
        ]
    }

    func fix(originalText: String) -> String {
        originalText.replacingOccurrences(of: "bad", with: "good")
    }
}
