import Foundation

/// A diagnostic produced by the Markdown linter.
///
/// Instances of ``Diagnostic`` encapsulate all of the metadata that describes an
/// issue detected by a lint rule, including the location in the source document,
/// the rule that triggered the diagnostic, and the edit that fixes it, if any. Use
/// diagnostics to communicate actionable feedback to end users and to tooling
/// that integrates with the linter.
public struct Diagnostic: Codable, Hashable {
  public enum Severity: String, Codable, Sendable { case info, warning, error }

  public let file: URL
  public let line: Int
  public let column: Int
  public let ruleID: String
  public let message: String
  public let severity: Severity
  public let fixIt: FixIt?

  /// Creates a new diagnostic instance.
  ///
  /// - Parameters:
  ///   - file: The file URL of the Markdown document that produced the diagnostic.
  ///   - line: The 1-based line number where the lint rule detected the issue.
  ///   - column: The 1-based column number of the issue's starting location, counted in
  ///     characters (grapheme clusters) from the start of the line.
  ///   - ruleID: The identifier of the lint rule that emitted the diagnostic.
  ///   - message: A human-readable description of the problem.
  ///   - severity: The severity classification for the diagnostic. The default value is ``Severity/warning``.
  ///   - fixIt: The edit that resolves the issue, when the rule can fix it automatically.
  public init(
    file: URL, line: Int, column: Int, ruleID: String, message: String,
    severity: Severity = .warning, fixIt: FixIt? = nil
  ) {
    self.file = file
    self.line = line
    self.column = column
    self.ruleID = ruleID
    self.message = message
    self.severity = severity
    self.fixIt = fixIt
  }

  /// A deterministic ordering predicate that sorts diagnostics by file path,
  /// then by line, column, and rule identifier.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side diagnostic to compare.
  ///   - rhs: The right-hand side diagnostic to compare.
  /// - Returns: `true` if `lhs` should appear before `rhs` in a sorted sequence.
  public static func sorter(lhs: Diagnostic, rhs: Diagnostic) -> Bool {
    if lhs.file.path != rhs.file.path { return lhs.file.path < rhs.file.path }
    if lhs.line != rhs.line { return lhs.line < rhs.line }
    if lhs.column != rhs.column { return lhs.column < rhs.column }
    return lhs.ruleID < rhs.ruleID
  }
}

/// An edit that fixes the issue a ``Diagnostic`` describes.
///
/// A fix-it replaces one range of the text that the rule was given with
/// ``replacement``. The range is written the way diagnostics locate issues:
/// 1-based lines, and 1-based columns counted in characters (grapheme
/// clusters). It starts at ``line`` and ``column`` and ends just before
/// ``endLine`` and ``endColumn``. A range whose start and end are equal
/// inserts text, and an empty replacement deletes the range.
///
/// ``Linter`` applies the fix-its of the diagnostics it reports. It skips a
/// fix-it whose range does not exist, overlaps a fix-it applied before it, or
/// reaches into code or raw HTML.
public struct FixIt: Codable, Hashable, Sendable {
  /// A short description of the edit for people, such as "スペースを削除".
  public let description: String
  /// The 1-based line on which the range starts.
  public let line: Int
  /// The 1-based column, counted in characters, at which the range starts.
  public let column: Int
  /// The 1-based line on which the range ends.
  public let endLine: Int
  /// The 1-based column, counted in characters, of the first character after the range.
  public let endColumn: Int
  /// The text that takes the place of the range.
  public let replacement: String

  /// Creates a fix-it that replaces a range of text.
  ///
  /// - Parameters:
  ///   - description: A short description of the edit for people.
  ///   - line: The 1-based line on which the range starts.
  ///   - column: The 1-based column, counted in characters, at which the range starts.
  ///   - endLine: The 1-based line on which the range ends.
  ///   - endColumn: The 1-based column, counted in characters, of the first character after
  ///     the range.
  ///   - replacement: The text that takes the place of the range.
  public init(
    description: String, line: Int, column: Int, endLine: Int, endColumn: Int, replacement: String
  ) {
    self.description = description
    self.line = line
    self.column = column
    self.endLine = endLine
    self.endColumn = endColumn
    self.replacement = replacement
  }
}
