import Foundation

/// A ``DiagnosticFormatStyle`` that emits GitHub Actions workflow commands.
///
/// ``GHADiagnosticFormatStyle`` serializes a ``Diagnostic`` as the workflow
/// command syntax that GitHub Actions interprets to surface annotations in the
/// Checks UI. The severity of the diagnostic determines the command type
/// (``Diagnostic/Severity/error`` → `error`, ``Diagnostic/Severity/warning`` →
/// `warning`, ``Diagnostic/Severity/info`` → `notice`). The diagnostic's
/// file path, line, and column are embedded into the command metadata, and the
/// message becomes the payload.
///
/// Percent signs and line breaks in the message (and additionally colons and
/// commas in the file path) are escaped according to GitHub's requirements so
/// that multi-line diagnostics render correctly. If the diagnostic includes a
/// fix-it suggestion, the suggestion is appended to the message in parentheses.
///
/// The resulting format matches the command style described in GitHub's
/// documentation, for example:
///
/// ```text
/// ::error file=app.js,line=10,col=15::Something went wrong
/// ```
public struct GHADiagnosticFormatStyle: DiagnosticFormatStyle {
  public typealias FormatInput = Diagnostic
  public typealias FormatOutput = String

  public init() {}

  public func format(_ diagnostic: Diagnostic) -> String {
    let level: String
    switch diagnostic.severity {
    case .error: level = "error"
    case .warning: level = "warning"
    case .info: level = "notice"
    }
    let message = diagnostic.message + (diagnostic.fixIt.map { " (fix: \($0))" } ?? "")
    let file = Self.escapeProperty(diagnostic.file.path)

    return
      "::\(level) file=\(file),line=\(diagnostic.line),col=\(diagnostic.column)::\(Self.escapeData(message))"
  }

  /// Escapes the message part of a workflow command.
  private static func escapeData(_ value: String) -> String {
    value
      .replacingOccurrences(of: "%", with: "%25")
      .replacingOccurrences(of: "\r", with: "%0D")
      .replacingOccurrences(of: "\n", with: "%0A")
  }

  /// Escapes a property value (such as `file`) of a workflow command.
  private static func escapeProperty(_ value: String) -> String {
    escapeData(value)
      .replacingOccurrences(of: ":", with: "%3A")
      .replacingOccurrences(of: ",", with: "%2C")
  }
}
