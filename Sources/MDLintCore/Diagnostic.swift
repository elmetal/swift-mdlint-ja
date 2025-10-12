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

public protocol DiagnosticFormatter {
    func format(_ d: Diagnostic) -> String
}

public struct TextDiagnosticFormatter: DiagnosticFormatter {
    public init() {}
    public func format(_ d: Diagnostic) -> String {
        let loc = "\(d.file.path):\(d.line):\(d.column)"
        let sev = d.severity.rawValue.uppercased()
        return "[\(sev)] \(loc) [\(d.ruleID)] \(d.message)"
    }
}

/// GitHub Actions workflow command format
/// ::error file=app.js,line=10,col=15::Something went wrong
public struct GHADiagnosticFormatter: DiagnosticFormatter {
    public init() {}
    public func format(_ d: Diagnostic) -> String {
        let level = (d.severity == .error) ? "error" : (d.severity == .warning ? "warning" : "notice")
        let escMsg = d.message.replacingOccurrences(of: "\n", with: "%0A")
        return "::<LEVEL> file=<FILE>,line=<LINE>,col=<COL>::<MSG>"
            .replacingOccurrences(of: "<LEVEL>", with: level)
            .replacingOccurrences(of: "<FILE>", with: d.file.path)
            .replacingOccurrences(of: "<LINE>", with: String(d.line))
            .replacingOccurrences(of: "<COL>", with: String(d.column))
            .replacingOccurrences(of: "<MSG>", with: escMsg + (d.fixIt.map { " (fix: \($0))" } ?? ""))
    }
}