import Foundation

/// A diagnostic produced by the Markdown linter.
///
/// Instances of ``Diagnostic`` encapsulate all of the metadata that describes an
/// issue detected by a lint rule, including the location in the source document,
/// the rule that triggered the diagnostic, and any suggested fix-it message. Use
/// diagnostics to communicate actionable feedback to end users and to tooling
/// that integrates with the linter.
public struct Diagnostic: Codable, Hashable {
    public enum Severity: String, Codable { case info, warning, error }

    public let file: URL
    public let line: Int
    public let column: Int
    public let ruleID: String
    public let message: String
    public let severity: Severity
    public let fixIt: String?

    /// Creates a new diagnostic instance.
    ///
    /// - Parameters:
    ///   - file: The file URL of the Markdown document that produced the diagnostic.
    ///   - line: The line number where the lint rule detected the issue.
    ///   - column: The column number of the issue's starting location.
    ///   - ruleID: The identifier of the lint rule that emitted the diagnostic.
    ///   - message: A human-readable description of the problem.
    ///   - severity: The severity classification for the diagnostic. The default value is ``Severity/warning``.
    ///   - fixIt: An optional fix-it string that proposes how to resolve the issue.
    public init(file: URL, line: Int, column: Int, ruleID: String, message: String, severity: Severity = .warning, fixIt: String? = nil) {
        self.file = file
        self.line = line
        self.column = column
        self.ruleID = ruleID
        self.message = message
        self.severity = severity
        self.fixIt = fixIt
    }

    /// Returns a deterministic ordering closure that sorts diagnostics by file path,
    /// then by line, column, and rule identifier.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side diagnostic to compare.
    ///   - rhs: The right-hand side diagnostic to compare.
    /// - Returns: `true` if ``lhs`` should appear before ``rhs`` in a sorted sequence.
    public static func sorter(lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        if lhs.file.path != rhs.file.path { return lhs.file.path < rhs.file.path }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        return lhs.ruleID < rhs.ruleID
    }
}
