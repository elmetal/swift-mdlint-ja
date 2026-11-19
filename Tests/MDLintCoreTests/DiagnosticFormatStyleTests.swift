import Foundation
import Testing

@testable import MDLintCore

private let sampleFileURL = URL(fileURLWithPath: "/tmp/sample.md")

@Suite("Text Diagnostic Format Style")
struct TextDiagnosticFormatStyleTests {
  private let diagnostic = Diagnostic(
    file: sampleFileURL,
    line: 4,
    column: 1,
    ruleID: "example.rule",
    message: "Informational message",
    severity: .info
  )

  @Test("Produces readable text output")
  func producesReadableTextOutput() {
    let formatter = TextDiagnosticFormatStyle()
    let formatted = formatter.format(diagnostic)

    #expect(formatted == "[INFO] \(sampleFileURL.path):4:1 [example.rule] Informational message")
  }

  @Test("Format closure matches direct method")
  func formatClosureMatchesDirectMethod() {
    let formatter = TextDiagnosticFormatStyle()
    let closure = formatter.format

    #expect(closure(diagnostic) == formatter.format(diagnostic))
  }
}

@Suite("GHA Diagnostic Format Style")
struct GHADiagnosticFormatStyleTests {
  @Test("Escapes newlines and appends fix-its")
  func escapesNewlinesAndAppendsFixIts() {
    let diagnostic = Diagnostic(
      file: sampleFileURL,
      line: 10,
      column: 2,
      ruleID: "example.rule",
      message: "First line\nSecond line",
      severity: .warning,
      fixIt: FixIt(
        description: "Update value", line: 10, column: 2, endLine: 10, endColumn: 3,
        replacement: "x")
    )

    let formatter = GHADiagnosticFormatStyle()
    let formatted = formatter.format(diagnostic)

    #expect(
      formatted
        == "::warning file=\(sampleFileURL.path),line=10,col=2::First line%0ASecond line (fix: Update value)"
    )
  }

  @Test("Maps severities to workflow levels using closure")
  func mapsSeveritiesToWorkflowLevelsUsingClosure() {
    let diagnostic = Diagnostic(
      file: sampleFileURL,
      line: 3,
      column: 5,
      ruleID: "example.rule",
      message: "Needs attention",
      severity: .info
    )

    let formatter = GHADiagnosticFormatStyle()
    let format = formatter.format

    #expect(
      format(diagnostic) == "::notice file=\(sampleFileURL.path),line=3,col=5::Needs attention")
  }

  @Test("Escapes workflow command metacharacters")
  func escapesWorkflowCommandMetacharacters() {
    let diagnostic = Diagnostic(
      file: URL(fileURLWithPath: "/tmp/a,b:c.md"),
      line: 1,
      column: 1,
      ruleID: "example.rule",
      message: "100% done\r\nnext",
      severity: .error,
      fixIt: FixIt(
        description: "line one\nline two", line: 1, column: 1, endLine: 1, endColumn: 2,
        replacement: "")
    )

    let formatted = GHADiagnosticFormatStyle().format(diagnostic)

    #expect(
      formatted
        == "::error file=/tmp/a%2Cb%3Ac.md,line=1,col=1::100%25 done%0D%0Anext (fix: line one%0Aline two)"
    )
  }
}
