import Foundation
import Markdown

/// The rules that the comments in a Markdown document turn off, line by line.
///
/// An author silences rules for part of a file with HTML comments:
///
/// - `<!-- mdlint-disable -->` turns every rule off, from the line of the
///   comment to the end of the file.
/// - `<!-- mdlint-enable -->` turns every rule back on, from the line of the
///   comment.
/// - `<!-- mdlint-disable-next-line -->` turns every rule off for the line
///   after the comment.
///
/// Each comment can name rule identifiers, separated by spaces or commas, to
/// limit itself to those rules, as in
/// `<!-- mdlint-disable ja.comma.max-three -->`. An identifier that belongs to
/// no rule has no effect.
///
/// A comment that ends on a line decides the state of that whole line. When
/// several comments end on one line, the last one wins.
///
/// Only comments that the parser reports as HTML are read, so a comment inside
/// a code block or a code span is not a directive.
struct DisableDirectives: Sendable {
  /// The state from each line that holds a `disable` or `enable` comment up to
  /// the next such line, in ascending order of lines.
  private var changes: [(line: Int, state: State)] = []

  /// What the `disable-next-line` comments turn off, keyed by the line they
  /// apply to.
  private var singleLines: [Int: State] = [:]

  /// Reads the directives from the HTML comments of a parsed document.
  init(document: Document) {
    var state = State()

    func read(_ rawHTML: String, startingAtLine firstLine: Int) {
      for comment in Self.comments(in: rawHTML) {
        guard let directive = Directive(commentBody: comment.body) else { continue }
        let line = firstLine + comment.lineOffset

        switch directive.kind {
        case .disable, .enable:
          state.set(disabled: directive.kind == .disable, for: directive.ruleIDs)
          if changes.last?.line == line {
            changes[changes.count - 1].state = state
          } else {
            changes.append((line, state))
          }
        case .disableNextLine:
          singleLines[line + 1, default: State()].set(disabled: true, for: directive.ruleIDs)
        }
      }
    }

    func visit(_ markup: Markup) {
      switch markup {
      case let html as HTMLBlock:
        if let range = html.range { read(html.rawHTML, startingAtLine: range.lowerBound.line) }
      case let html as InlineHTML:
        if let range = html.range { read(html.rawHTML, startingAtLine: range.lowerBound.line) }
      default:
        for child in markup.children { visit(child) }
      }
    }

    visit(document)
  }

  /// A Boolean value that indicates whether the document has no directives.
  var isEmpty: Bool { changes.isEmpty && singleLines.isEmpty }

  /// Returns whether the rule is turned off on the given 1-based line.
  func disables(_ ruleID: String, atLine line: Int) -> Bool {
    if singleLines[line]?.disables(ruleID) == true { return true }
    return changes.last(where: { $0.line <= line })?.state.disables(ruleID) ?? false
  }

  /// Undoes an automatic fix on the lines where its rule is turned off.
  ///
  /// - Parameters:
  ///   - text: The text before the fix.
  ///   - fixed: The text after the fix.
  ///   - ruleID: The identifier of the rule that made the fix.
  /// - Returns: `fixed`, with every line on which the rule is off taken from
  ///   `text`. `nil` when the fix changed the number of lines: the lines of the
  ///   two texts then no longer correspond, and neither do the line numbers of
  ///   the directives.
  func keepingDisabledLines(of text: String, in fixed: String, for ruleID: String) -> String? {
    let originalLines = LineIndex(text)
    let fixedLines = LineIndex(fixed)
    guard originalLines.lineCount == fixedLines.lineCount else { return nil }

    var result = ""
    var nextChange = changes.startIndex
    var isDisabled = false
    for line in 1...originalLines.lineCount {
      while nextChange < changes.endIndex, changes[nextChange].line <= line {
        isDisabled = changes[nextChange].state.disables(ruleID)
        nextChange += 1
      }
      if isDisabled || singleLines[line]?.disables(ruleID) == true {
        result += text[originalLines.range(ofLine: line)]
      } else {
        result += fixed[fixedLines.range(ofLine: line)]
      }
    }
    return result
  }
}

// MARK: - State

extension DisableDirectives {
  /// The rules that are turned off at one point of the document.
  private struct State: Sendable {
    /// Whether the rules that are not in `exceptions` are off.
    private var disablesAllRules = false
    /// The rules whose state is the opposite of `disablesAllRules`.
    private var exceptions: Set<String> = []

    func disables(_ ruleID: String) -> Bool {
      disablesAllRules != exceptions.contains(ruleID)
    }

    /// Turns the given rules off or on. An empty set stands for every rule.
    mutating func set(disabled: Bool, for ruleIDs: Set<String>) {
      if ruleIDs.isEmpty {
        disablesAllRules = disabled
        exceptions = []
      } else if disablesAllRules == disabled {
        exceptions.subtract(ruleIDs)
      } else {
        exceptions.formUnion(ruleIDs)
      }
    }
  }
}

// MARK: - Reading comments

extension DisableDirectives {
  private struct Directive {
    enum Kind: String {
      case disable = "mdlint-disable"
      case enable = "mdlint-enable"
      case disableNextLine = "mdlint-disable-next-line"
    }

    let kind: Kind
    /// The rules the directive names. Empty when it applies to every rule.
    let ruleIDs: Set<String>

    /// Parses the text between `<!--` and `-->`. Returns `nil` for a comment
    /// that is not a directive.
    init?(commentBody: Substring) {
      let words = commentBody.split(whereSeparator: { $0.isWhitespace || $0 == "," })
      guard let keyword = words.first, let kind = Kind(rawValue: String(keyword)) else {
        return nil
      }
      self.kind = kind
      self.ruleIDs = Set(words.dropFirst().map(String.init))
    }
  }

  /// Finds the comments in a piece of raw HTML.
  ///
  /// - Returns: The text between the delimiters of each comment, and the
  ///   number of line breaks that precede the end of the comment.
  private static func comments(in rawHTML: String) -> [(body: Substring, lineOffset: Int)] {
    var comments: [(body: Substring, lineOffset: Int)] = []
    var lineOffset = 0
    var counted = rawHTML.startIndex
    var searchStart = rawHTML.startIndex

    while let opening = rawHTML.range(of: "<!--", range: searchStart..<rawHTML.endIndex),
      let closing = rawHTML.range(of: "-->", range: opening.upperBound..<rawHTML.endIndex)
    {
      // "\r\n" is a single character, so each line break counts once.
      lineOffset += rawHTML[counted..<closing.upperBound].count(where: \.isNewline)
      counted = closing.upperBound
      comments.append((rawHTML[opening.upperBound..<closing.lowerBound], lineOffset))
      searchStart = closing.upperBound
    }
    return comments
  }
}
