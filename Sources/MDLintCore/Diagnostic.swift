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
