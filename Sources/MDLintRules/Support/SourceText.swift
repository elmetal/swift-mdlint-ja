/// Shared helpers for rules that scan the raw Markdown source.
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

  /// Returns the text with `transform` applied to every line, keeping each
  /// original line terminator untouched.
  ///
  /// Lines whose 1-based number is in `skippedLineNumbers` are copied verbatim.
  func mappingSourceLines(
    skipping skippedLineNumbers: Set<Int> = [], _ transform: (Substring) -> String
  ) -> String {
    var result = ""
    var lineStart = startIndex
    var lineNumber = 1

    func appendLine(_ line: Substring) {
      if skippedLineNumbers.contains(lineNumber) {
        result += line
      } else {
        result += transform(line)
      }
    }

    for index in indices where self[index].isLineTerminator {
      appendLine(self[lineStart..<index])
      result.append(self[index])
      lineStart = self.index(after: index)
      lineNumber += 1
    }
    appendLine(self[lineStart...])
    return result
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
