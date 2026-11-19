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

    let (diagnostics, fixed) = linter.lint(
      content: content, fileURL: sampleFileURL, applyFixes: false)

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

    let (diagnostics, fixed) = linter.lint(
      content: content, fileURL: sampleFileURL, applyFixes: true)

    #expect(diagnostics.count == 1)
    #expect(fixed == "good value")
  }

  @Test func reportsTheDiagnosticsOfTheOriginalContentWhenFixing() throws {
    let linter = Linter(rules: [ReplaceBadRule()])

    let (diagnostics, fixed) = linter.lint(
      content: "ok\nbad bad", fileURL: sampleFileURL, applyFixes: true)

    // The rule reports one occurrence per pass, so fixing takes two passes,
    // and the diagnostics are still the ones of the first.
    #expect(fixed == "ok\ngood good")
    #expect(diagnostics.map(\.column) == [1])
    #expect(diagnostics.first?.fixIt?.replacement == "good")
  }
}

@Suite("Diagnostic Sorting")
struct DiagnosticSortingTests {
  @Test func sortsByFileLineColumnAndRule() {
    let base = URL(fileURLWithPath: "/tmp")
    let diagA1 = Diagnostic(
      file: base.appendingPathComponent("a.md"), line: 1, column: 2, ruleID: "b", message: "")
    let diagA2 = Diagnostic(
      file: base.appendingPathComponent("a.md"), line: 1, column: 2, ruleID: "a", message: "")
    let diagB = Diagnostic(
      file: base.appendingPathComponent("b.md"), line: 1, column: 1, ruleID: "a", message: "")
    let diagEarlierLine = Diagnostic(
      file: base.appendingPathComponent("a.md"), line: 0, column: 5, ruleID: "z", message: "")
    let diagLaterColumn = Diagnostic(
      file: base.appendingPathComponent("a.md"), line: 1, column: 3, ruleID: "a", message: "")

    let sorted = [diagA1, diagA2, diagB, diagEarlierLine, diagLaterColumn].sorted(
      by: Diagnostic.sorter)

    #expect(sorted == [diagEarlierLine, diagA2, diagA1, diagLaterColumn, diagB])
  }
}

private struct ReplaceBadRule: Rule {
  let id = "test.replace-bad"
  let description = "Replaces the word 'bad' with 'good'"

  func check(document _: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    guard let range = originalText.range(of: "bad") else { return [] }
    let linesBefore = originalText[..<range.lowerBound].split(
      separator: "\n", omittingEmptySubsequences: false)
    let line = linesBefore.count
    let column = (linesBefore.last?.count ?? 0) + 1

    return [
      Diagnostic(
        file: fileURL,
        line: line,
        column: column,
        ruleID: id,
        message: "Replace 'bad' with 'good'",
        fixIt: FixIt(
          description: "Replace with 'good'", line: line, column: column, endLine: line,
          endColumn: column + 3, replacement: "good")
      )
    ]
  }
}
