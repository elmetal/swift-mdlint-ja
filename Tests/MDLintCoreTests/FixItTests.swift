import Foundation
import Markdown
import Testing

@testable import MDLintCore

private let fileURL = URL(fileURLWithPath: "/tmp/fix-it.md")

private func fixed(_ content: String, rules: [Rule]) -> String? {
  Linter(rules: rules).lint(content: content, fileURL: fileURL, applyFixes: true).1
}

/// A fix-it that replaces part of one line.
private func edit(_ line: Int, _ column: Int, length: Int = 0, with replacement: String) -> FixIt {
  FixIt(
    description: "edit", line: line, column: column, endLine: line, endColumn: column + length,
    replacement: replacement)
}

@Suite("Fix-its")
struct FixItTests {
  // MARK: Kinds of edits

  @Test func replacesDeletesAndInserts() {
    let rule = ScriptedRule { text in
      text == "abc def ghi\n"
        ? [
          edit(1, 1, length: 3, with: "ABCD"), edit(1, 5, length: 4, with: ""),
          edit(1, 12, with: "!"),
        ]
        : []
    }

    #expect(fixed("abc def ghi\n", rules: [rule]) == "ABCD ghi!\n")
  }

  @Test func appliesEditsWhateverTheOrderTheyAreReportedIn() {
    let rule = ScriptedRule { text in
      text == "one\ntwo\nthree\n"
        ? [
          edit(3, 1, length: 5, with: "3"), edit(1, 1, length: 3, with: "1"),
          edit(2, 1, length: 3, with: "2"),
        ]
        : []
    }

    #expect(fixed("one\ntwo\nthree\n", rules: [rule]) == "1\n2\n3\n")
  }

  @Test func replacesARangeThatSpansLines() {
    let rule = ScriptedRule { text in
      text == "first line\nsecond line\nthird\n"
        ? [
          FixIt(
            description: "join", line: 1, column: 6, endLine: 2, endColumn: 7, replacement: " and")
        ] : []
    }

    #expect(fixed("first line\nsecond line\nthird\n", rules: [rule]) == "first and line\nthird\n")
  }

  @Test func insertsAtTheEndOfTheText() {
    let withNewline = ScriptedRule { $0 == "a\n" ? [edit(2, 1, with: "b\n")] : [] }
    let withoutNewline = ScriptedRule { $0 == "a" ? [edit(1, 2, with: "\n")] : [] }

    #expect(fixed("a\n", rules: [withNewline]) == "a\nb\n")
    #expect(fixed("a", rules: [withoutNewline]) == "a\n")
  }

  @Test func countsColumnsInCharacters() {
    // "か゚" and the family emoji are one character each, of several scalars.
    let content = "か\u{309A}👨‍👩‍👧bad\n"
    let rule = ScriptedRule { $0 == content ? [edit(1, 3, length: 3, with: "good")] : [] }

    #expect(fixed(content, rules: [rule]) == "か\u{309A}👨‍👩‍👧good\n")
  }

  @Test(arguments: ["\n", "\r\n", "\r"])
  func keepsLineEndings(lineEnding: String) {
    let content = ["bad", "", "bad", ""].joined(separator: lineEnding)
    let rule = ScriptedRule { text in
      guard text == content else { return [] }
      return [
        edit(1, 1, length: 3, with: "good"),
        // Deletes the blank line together with its line ending.
        FixIt(description: "delete", line: 2, column: 1, endLine: 3, endColumn: 1, replacement: ""),
        edit(3, 4, with: "!"),
      ]
    }

    #expect(fixed(content, rules: [rule]) == ["good", "bad!", ""].joined(separator: lineEnding))
  }

  @Test func doesNotTreatAFormFeedAsALineEnding() {
    // The parser and the rules end a line at LF, CRLF, and CR only.
    let content = "a\u{0C}bad\n"
    let rule = ScriptedRule { $0 == content ? [edit(1, 3, length: 3, with: "good")] : [] }

    #expect(fixed(content, rules: [rule]) == "a\u{0C}good\n")
  }

  // MARK: Edits that cannot be applied

  @Test(arguments: [
    FixIt(description: "", line: 3, column: 1, endLine: 3, endColumn: 2, replacement: "x"),
    FixIt(description: "", line: 0, column: 1, endLine: 1, endColumn: 2, replacement: "x"),
    FixIt(description: "", line: 1, column: 0, endLine: 1, endColumn: 2, replacement: "x"),
    FixIt(description: "", line: 1, column: 5, endLine: 1, endColumn: 6, replacement: "x"),
    FixIt(description: "", line: 1, column: 2, endLine: 1, endColumn: 9, replacement: "x"),
    FixIt(description: "", line: 1, column: 3, endLine: 1, endColumn: 2, replacement: "x"),
    FixIt(description: "", line: 2, column: 1, endLine: 1, endColumn: 1, replacement: "x"),
  ])
  func skipsAFixItWhoseRangeDoesNotExist(invalid: FixIt) {
    let rule = ScriptedRule { $0 == "abc\n" ? [invalid, edit(1, 1, length: 1, with: "A")] : [] }

    // The valid fix-it reported next to it is still applied.
    #expect(fixed("abc\n", rules: [rule]) == "Abc\n")
  }

  @Test func returnsTheContentUnchangedWhenNoFixItApplies() {
    let nothing = ScriptedRule { _ in [] }
    let invalid = ScriptedRule { _ in [edit(9, 9, with: "x")] }
    let noOp = ScriptedRule { _ in [edit(1, 1, length: 3, with: "abc")] }

    #expect(fixed("abc\r\n", rules: [nothing]) == "abc\r\n")
    #expect(fixed("abc\r\n", rules: [invalid]) == "abc\r\n")
    #expect(fixed("abc\r\n", rules: [noOp]) == "abc\r\n")
  }

  // MARK: Overlapping edits

  @Test func appliesTheEarlierOfTwoOverlappingEditsFirst() {
    let ab = WordRule(id: "test.ab", word: "ab", replacement: "x")
    let bc = WordRule(id: "test.bc", word: "bc", replacement: "y")

    // "ab" starts earlier, and once it is replaced nothing is left for the other rule.
    #expect(fixed("abc", rules: [ab, bc]) == "xc")
    #expect(fixed("abc", rules: [bc, ab]) == "xc")
  }

  @Test func appliesTheEditOfTheEarlierRuleWhenTwoStartTogether() {
    let toFullWidth = WordRule(id: "test.fullwidth", word: ".", replacement: "。")
    let delete = WordRule(id: "test.delete", word: ".", replacement: "")

    #expect(fixed("end.", rules: [toFullWidth, delete]) == "end。")
    #expect(fixed("end.", rules: [delete, toFullWidth]) == "end")
  }

  @Test func appliesTheOtherEditInTheNextPassWhenItsViolationRemains() {
    let period = WordRule(id: "test.period", word: ".", replacement: "。")
    let heading = WordRule(id: "test.heading", word: "。", replacement: "")
    let both = ScriptedRule { text in
      // Two edits for the same character: only the first can be applied at once.
      text == "# title.\n"
        ? [edit(1, 8, length: 1, with: "。"), edit(1, 8, length: 1, with: "")] : []
    }

    #expect(fixed("# title.\n", rules: [both]) == "# title。\n")
    #expect(fixed("# title.\n", rules: [period, heading]) == "# title\n")
  }

  @Test func appliesAdjacentEdits() {
    let rule = ScriptedRule { text in
      text == "abcdef"
        ? [
          edit(1, 1, length: 2, with: "1"), edit(1, 3, length: 2, with: "2"),
          edit(1, 5, length: 2, with: "3"),
        ]
        : []
    }

    #expect(fixed("abcdef", rules: [rule]) == "123")
  }

  @Test func appliesOnlyOneInsertionAtAPositionPerPass() {
    let rule = ScriptedRule { text in
      text == "ac" ? [edit(1, 2, with: "b"), edit(1, 2, with: "B")] : []
    }

    #expect(fixed("ac", rules: [rule]) == "abc")
  }

  // MARK: Passes

  @Test func repeatsUntilNothingIsLeftToFix() {
    let star = WordRule(id: "test.star", word: "*", replacement: "")
    let ab = WordRule(id: "test.ab", word: "ab", replacement: "c")
    let cc = WordRule(id: "test.cc", word: "cc", replacement: "d")

    // Removing the stars creates "ab", and replacing those creates "cc".
    #expect(fixed("a*ba*b", rules: [cc, ab, star]) == "d")
  }

  @Test func stopsWhenRulesKeepUndoingEachOther() throws {
    let toB = WordRule(id: "test.a", word: "a", replacement: "b")
    let toA = WordRule(id: "test.b", word: "b", replacement: "a")

    let result = try #require(fixed("a", rules: [toB, toA]))

    #expect(result == "a" || result == "b")
  }

  // MARK: Code and raw HTML

  @Test func appliesEditsNextToCode() {
    let content = "前 `code` 後\n"
    let rule = ScriptedRule { text in
      // The spaces on both sides of the code span are deleted, and text is
      // inserted right before and right after it.
      text.hasPrefix("前 ")
        ? [edit(1, 2, length: 1, with: ""), edit(1, 9, length: 1, with: "")]
        : text.hasPrefix("前\u{FFFC}") ? [edit(1, 2, with: "「"), edit(1, 8, with: "」")] : []
    }

    #expect(fixed(content, rules: [rule]) == "前「`code`」後\n")
  }

  @Test func appliesEditsBetweenTwoHiddenRegions() {
    let rule = ScriptedRule { text in
      text.contains(" と ") ? [edit(1, 5, length: 1, with: "and"), edit(3, 4, with: "x")] : []
    }

    // The second edit inserts between two HTML tags that touch each other.
    #expect(
      fixed("`a` と `b`\n\n<b><i>強調</i></b>\n", rules: [rule])
        == "`a` and `b`\n\n<b>x<i>強調</i></b>\n")
  }

  @Test(arguments: [
    // Replaces the opening backtick.
    edit(1, 3, length: 1, with: "x"),
    // Starts in the prose and reaches into the code span.
    edit(1, 1, length: 4, with: "x"),
    // Starts in the code span and reaches into the prose.
    edit(1, 7, length: 3, with: "x"),
    // Covers the whole code span.
    edit(1, 2, length: 8, with: "x"),
    // Inserts in the middle of the code span.
    edit(1, 5, with: "x"),
    // Would add a character that the linter uses as a placeholder.
    edit(1, 1, length: 1, with: "\u{FFFC}"),
    edit(1, 1, with: "\u{E000}"),
  ])
  func skipsAFixItThatTouchesCode(invalid: FixIt) {
    let content = "前 `code` 後\n"
    let rule = ScriptedRule { $0.hasPrefix("前 ") ? [invalid] : [] }

    #expect(fixed(content, rules: [rule]) == content)
  }

  @Test func skipsAFixItInsideACodeBlockOrHTML() {
    let content = "text\n\n```\ncode\n```\n\n<div>\nhtml\n</div>\n"
    let rule = ScriptedRule { text in
      text.hasPrefix("text")
        ? [
          edit(4, 1, length: 4, with: "x"), edit(4, 3, with: "x"),
          // Joining the fence with the code would also remove hidden characters.
          FixIt(description: "", line: 3, column: 4, endLine: 4, endColumn: 1, replacement: ""),
          edit(8, 1, length: 4, with: "x"), edit(1, 1, length: 4, with: "TEXT"),
        ] : []
    }

    #expect(fixed(content, rules: [rule]) == "TEXT\n\n```\ncode\n```\n\n<div>\nhtml\n</div>\n")
  }
}

/// Reports the fix-its that a closure returns for the text it is given.
private struct ScriptedRule: Rule {
  let id = "test.scripted"
  let description = "Reports scripted fix-its"
  let fixIts: @Sendable (String) -> [FixIt]

  init(_ fixIts: @escaping @Sendable (String) -> [FixIt]) {
    self.fixIts = fixIts
  }

  func check(document _: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    fixIts(originalText).map {
      Diagnostic(
        file: fileURL, line: $0.line, column: $0.column, ruleID: id, message: $0.description,
        fixIt: $0)
    }
  }
}

/// Reports every occurrence of a word on a line with a fix-it that replaces it.
private struct WordRule: Rule {
  let id: String
  let word: String
  let replacement: String

  var description: String { "Replaces '\(word)' with '\(replacement)'" }

  func check(document _: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let lines = originalText.split(separator: "\n", omittingEmptySubsequences: false)
    for (index, line) in lines.enumerated() {
      for range in line.ranges(of: word) {
        let column = line.distance(from: line.startIndex, to: range.lowerBound) + 1
        diagnostics.append(
          Diagnostic(
            file: fileURL, line: index + 1, column: column, ruleID: id, message: description,
            fixIt: FixIt(
              description: description, line: index + 1, column: column, endLine: index + 1,
              endColumn: column + word.count, replacement: replacement)))
      }
    }
    return diagnostics
  }
}
