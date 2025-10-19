import Foundation

/// A ``DiagnosticFormatStyle`` that emits GitHub Actions workflow commands.
///
/// ``GHADiagnosticFormatStyle`` serializes a ``Diagnostic`` as the workflow
/// command syntax that GitHub Actions interprets to surface annotations in the
/// Checks UI. The severity of the diagnostic determines the command type
/// (``Diagnostic.Severity/error`` → ``error``, ``Diagnostic.Severity/warning`` →
/// ``warning``, ``Diagnostic.Severity/info`` → ``notice``). The diagnostic's
/// file path, line, and column are embedded into the command metadata, and the
/// message becomes the payload.
///
/// Newlines in the diagnostic message are escaped according to GitHub's
/// requirements so that multi-line diagnostics render correctly. If the
/// diagnostic includes a fix-it suggestion, the suggestion is appended to the
/// message in parentheses.
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
        let escapedMessage = diagnostic.message.replacingOccurrences(of: "\n", with: "%0A")
        let messageWithFixIt = escapedMessage + (diagnostic.fixIt.map { " (fix: \($0))" } ?? "")

        return "::<LEVEL> file=<FILE>,line=<LINE>,col=<COL>::<MSG>"
            .replacingOccurrences(of: "<LEVEL>", with: level)
            .replacingOccurrences(of: "<FILE>", with: diagnostic.file.path)
            .replacingOccurrences(of: "<LINE>", with: String(diagnostic.line))
            .replacingOccurrences(of: "<COL>", with: String(diagnostic.column))
            .replacingOccurrences(of: "<MSG>", with: messageWithFixIt)
    }
}
