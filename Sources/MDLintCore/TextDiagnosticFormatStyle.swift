import Foundation

/// A ``DiagnosticFormatStyle`` that renders diagnostics as plain text.
///
/// ``TextDiagnosticFormatStyle`` produces human-readable strings that combine
/// the diagnostic's severity, file location, rule identifier, and message.
/// This style works well for terminal output or log files where plain text is
/// preferred over structured annotations.
public struct TextDiagnosticFormatStyle: DiagnosticFormatStyle {
    public typealias FormatInput = Diagnostic
    public typealias FormatOutput = String

    public init() {}

    public func format(_ diagnostic: Diagnostic) -> String {
        let location = "\(diagnostic.file.path):\(diagnostic.line):\(diagnostic.column)"
        let severity = diagnostic.severity.rawValue.uppercased()
        return "[\(severity)] \(location) [\(diagnostic.ruleID)] \(diagnostic.message)"
    }
}
