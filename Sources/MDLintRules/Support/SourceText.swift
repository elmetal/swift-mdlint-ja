import MDLintCore

/// Shared helpers for rules that scan the Markdown source.
///
/// The linter hides code and raw HTML before it hands the source to a rule
/// (see `MaskedSource`), so these helpers do not need to know about either.
///
/// Lines can be terminated by LF, CRLF, or CR. Swift treats CRLF as a single
/// `Character`, so comparing against "\n" alone misses Windows line endings;
/// every rule should go through these helpers instead.

extension Character {
  /// Whether the character terminates a line in Markdown source (LF, CRLF, or CR).
  var isLineTerminator: Bool {
    self == "\n" || self == "\r\n" || self == "\r"
  }
}

extension String {
  /// The lines of the text without their line terminators.
  ///
  /// The substrings share indices with the receiver.
  var sourceLines: [Substring] {
    split(omittingEmptySubsequences: false, whereSeparator: \.isLineTerminator)
  }

  /// Returns the 1-based line and column (counted in characters) of `index`.
  func lineAndColumn(of index: Index) -> (line: Int, column: Int) {
    var line = 1
    var column = 1
    for character in self[..<index] {
      if character.isLineTerminator {
        line += 1
        column = 1
      } else {
        column += 1
      }
    }
    return (line, column)
  }
}

extension StringProtocol {
  /// The index just past the last character that is neither a space nor a tab.
  var endIndexIgnoringTrailingSpacesAndTabs: Index {
    var end = endIndex
    while end > startIndex {
      let previous = index(before: end)
      guard self[previous] == " " || self[previous] == "\t" else { break }
      end = previous
    }
    return end
  }
}

extension FixIt {
  /// Creates a fix-it that replaces part of one line.
  ///
  /// - Parameters:
  ///   - description: A short description of the edit for people.
  ///   - range: The part of `line` to replace.
  ///   - line: A line of the text the rule was given, without its line terminator.
  ///   - lineNumber: The 1-based number of `line`.
  ///   - replacement: The text that takes the place of `range`.
  init(
    description: String, replacing range: Range<Substring.Index>, in line: Substring,
    lineNumber: Int, with replacement: String
  ) {
    let column = line.distance(from: line.startIndex, to: range.lowerBound) + 1
    self.init(
      description: description,
      line: lineNumber,
      column: column,
      endLine: lineNumber,
      endColumn: column + line.distance(from: range.lowerBound, to: range.upperBound),
      replacement: replacement)
  }
}
