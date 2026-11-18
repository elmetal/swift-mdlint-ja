import Markdown

/// The places where the block structure of a Markdown document ends a sentence.
///
/// A sentence never continues from one block into the next: a list item, a
/// heading, a table row, or a paragraph that follows another block without a
/// blank line each start a new sentence, whether or not the text before them
/// ends in a terminator. Inside a table, every cell holds its own sentences.
struct SentenceBreaks {
  /// The 1-based numbers of the lines on which a block starts.
  private let blockStartLines: Set<Int>
  /// The 1-based numbers of the lines that belong to a table.
  private let tableLines: Set<Int>

  fileprivate init(blockStartLines: Set<Int>, tableLines: Set<Int>) {
    self.blockStartLines = blockStartLines
    self.tableLines = tableLines
  }

  /// Whether a block starts on the given 1-based line, which ends the sentence
  /// on the line before it.
  func startsBlock(atLine line: Int) -> Bool {
    blockStartLines.contains(line)
  }

  /// Whether `character`, found on the given 1-based line, is a pipe that
  /// separates two table cells.
  ///
  /// - Parameter previous: The character before `character` on the same line.
  ///   A pipe that follows a backslash is escaped and belongs to the cell.
  func separatesTableCells(
    _ character: Character, after previous: Character?, onLine line: Int
  ) -> Bool {
    character == "|" && previous != "\\" && tableLines.contains(line)
  }
}

extension Document {
  /// The sentence breaks that follow from the block structure of the document.
  var sentenceBreaks: SentenceBreaks {
    var blockStartLines: Set<Int> = []
    var tableLines: Set<Int> = []

    func visit(_ markup: Markup) {
      for child in markup.children where !(child is InlineMarkup) {
        if let range = child.range {
          blockStartLines.insert(range.lowerBound.line)
          if child is Table {
            tableLines.formUnion(range.lowerBound.line...range.upperBound.line)
          }
        }
        visit(child)
      }
    }
    visit(self)

    return SentenceBreaks(blockStartLines: blockStartLines, tableLines: tableLines)
  }
}
