import Foundation

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
