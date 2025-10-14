import Foundation

public struct Diagnostic: Codable, Hashable {
    public enum Severity: String, Codable { case info, warning, error }

    public let file: URL
    public let line: Int
    public let column: Int
    public let ruleID: String
    public let message: String
    public let severity: Severity
    public let fixIt: String?

    public init(file: URL, line: Int, column: Int, ruleID: String, message: String, severity: Severity = .warning, fixIt: String? = nil) {
        self.file = file
        self.line = line
        self.column = column
        self.ruleID = ruleID
        self.message = message
        self.severity = severity
        self.fixIt = fixIt
    }

    public static func sorter(lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        if lhs.file.path != rhs.file.path { return lhs.file.path < rhs.file.path }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        return lhs.ruleID < rhs.ruleID
    }
}

public protocol DiagnosticFormatStyle: FormatStyle where FormatInput == Diagnostic {}

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

/// GitHub Actions workflow command format
/// ::error file=app.js,line=10,col=15::Something went wrong
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

public struct AnyDiagnosticFormatStyle: DiagnosticFormatStyle {
    public typealias FormatInput = Diagnostic
    public typealias FormatOutput = String

    private let formatter: (Diagnostic) -> String

    public init<S: DiagnosticFormatStyle>(_ style: S) where S.FormatOutput == String {
        self.formatter = style.format
    }

    public func format(_ diagnostic: Diagnostic) -> String {
        formatter(diagnostic)
    }
}
