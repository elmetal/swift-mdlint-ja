import Markdown

/// The source ranges of inline code spans, backtick delimiters included.
///
/// Rules that check Japanese prose use this to leave inline code alone.
struct InlineCodeRanges {
  /// Sorted by position and non-overlapping.
  private let ranges: [Range<String.Index>]

  static let none = InlineCodeRanges([])

  init(_ ranges: [Range<String.Index>]) {
    self.ranges = ranges.sorted { $0.lowerBound < $1.lowerBound }
  }

  /// Returns the inline code span that covers `index`, if any.
  func range(containing index: String.Index) -> Range<String.Index>? {
    // Binary search for the first span that ends after `index`.
    var low = 0
    var high = ranges.count
    while low < high {
      let middle = (low + high) / 2
      if ranges[middle].upperBound <= index {
        low = middle + 1
      } else {
        high = middle
      }
    }
    guard low < ranges.count, ranges[low].contains(index) else { return nil }
    return ranges[low]
  }

  func contains(_ index: String.Index) -> Bool {
    range(containing: index) != nil
  }
}

extension Document {
  /// Locates every inline code span of the document in `source`, the text the
  /// document was parsed from.
  ///
  /// The parser reports positions as UTF-8 columns. A reported span is trusted
  /// only when it really starts and ends with a backtick in `source`: a leading
  /// tab shifts the reported columns, and so does the indentation or `>` marker
  /// in front of a span that continues on the next line of a list item or block
  /// quote. The reported lines are still right in those cases, so they are
  /// scanned for backtick runs instead.
  func inlineCodeRanges(in source: String) -> InlineCodeRanges {
    let lines = source.sourceLines
    let backtick = UInt8(ascii: "`")
    var ranges: [Range<String.Index>] = []
    var unresolvedLineRanges: [ClosedRange<Int>] = []

    func index(of location: SourceLocation) -> String.Index? {
      guard lines.indices.contains(location.line - 1), location.column >= 1 else { return nil }
      let line = lines[location.line - 1]
      return line.utf8.index(
        line.startIndex, offsetBy: location.column - 1, limitedBy: line.endIndex)
    }

    func visit(_ markup: Markup) {
      for child in markup.children {
        if let inlineCode = child as? InlineCode {
          guard let reported = inlineCode.range else { continue }
          if let lower = index(of: reported.lowerBound),
            let upper = index(of: reported.upperBound),
            lower < upper,
            source.utf8[lower] == backtick,
            source.utf8[source.utf8.index(before: upper)] == backtick
          {
            ranges.append(lower..<upper)
          } else {
            let first = min(reported.lowerBound.line, reported.upperBound.line)
            let last = max(reported.lowerBound.line, reported.upperBound.line)
            unresolvedLineRanges.append(first...last)
          }
        } else if child.childCount > 0 {
          visit(child)
        }
      }
    }

    visit(self)

    for lineRange in unresolvedLineRanges.sorted(by: { $0.lowerBound < $1.lowerBound })
    where lines.indices.contains(lineRange.lowerBound - 1)
      && lines.indices.contains(lineRange.upperBound - 1)
    {
      let region =
        source[
          lines[lineRange.lowerBound - 1].startIndex..<lines[lineRange.upperBound - 1].endIndex]
      for span in BacktickScanner.scan(region, skipping: InlineCodeRanges(ranges)).spans
      where !ranges.contains(where: { $0.overlaps(span) }) {
        ranges.append(span)
      }
    }

    return InlineCodeRanges(ranges)
  }
}

/// Pairs backtick runs within a piece of source text the way CommonMark does.
///
/// A run of N backticks opens a code span that is closed by the next run of
/// exactly N backticks; a run without such a partner is literal text. A
/// backslash escapes the following character outside of code spans.
enum BacktickScanner {
  /// Scans `line` (or several consecutive lines of one paragraph), treating the
  /// spans in `known` as already matched.
  ///
  /// - Returns: The code spans found in the text (delimiters included) and the
  ///   start of the first backtick run that has no closing run.
  static func scan(_ line: Substring, skipping known: InlineCodeRanges = .none)
    -> (spans: [Range<String.Index>], firstUnmatched: String.Index?)
  {
    var spans: [Range<String.Index>] = []
    var firstUnmatched: String.Index?
    var current = line.startIndex

    while current < line.endIndex {
      if let knownSpan = known.range(containing: current) {
        current = min(knownSpan.upperBound, line.endIndex)
        continue
      }

      if line[current] == "\\" {
        // Skip the escaped character, whatever it is.
        current = line.index(after: current)
        if current < line.endIndex { current = line.index(after: current) }
        continue
      }

      guard line[current] == "`" else {
        current = line.index(after: current)
        continue
      }

      let opener = backtickRun(in: line, from: current)
      let length = line.distance(from: opener.lowerBound, to: opener.upperBound)
      var search = opener.upperBound
      var closer: Range<String.Index>?
      while let next = line[search...].firstIndex(of: "`") {
        if let knownSpan = known.range(containing: next) {
          search = min(knownSpan.upperBound, line.endIndex)
          continue
        }
        let run = backtickRun(in: line, from: next)
        if line.distance(from: run.lowerBound, to: run.upperBound) == length {
          closer = run
          break
        }
        search = run.upperBound
      }

      if let closer {
        spans.append(opener.lowerBound..<closer.upperBound)
        current = closer.upperBound
      } else {
        if firstUnmatched == nil { firstUnmatched = opener.lowerBound }
        current = opener.upperBound
      }
    }

    return (spans, firstUnmatched)
  }

  private static func backtickRun(in line: Substring, from start: String.Index)
    -> Range<String.Index>
  {
    var end = start
    while end < line.endIndex, line[end] == "`" {
      end = line.index(after: end)
    }
    return start..<end
  }
}
