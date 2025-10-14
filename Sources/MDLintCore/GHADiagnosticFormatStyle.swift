import Foundation

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
