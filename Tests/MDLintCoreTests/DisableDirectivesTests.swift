import Foundation
import Markdown
import Testing

@testable import MDLintCore

private let sampleFileURL = URL(fileURLWithPath: "/tmp/sample.md")

private let bad = WordRule(id: "test.no-bad", word: "bad", replacement: "good")
private let ugly = WordRule(id: "test.no-ugly", word: "ugly", replacement: "nice")

/// Returns the lines on which `rule` is reported, in ascending order.
private func reportedLines(
  in content: String, of rule: WordRule = bad, rules: [Rule] = [bad, ugly]
) -> [Int] {
  Linter(rules: rules)
    .lint(content: content, fileURL: sampleFileURL, applyFixes: false).0
    .filter { $0.ruleID == rule.id }
    .map(\.line)
    .sorted()
}

private func fixed(_ content: String, rules: [Rule] = [bad, ugly]) -> String? {
  Linter(rules: rules).lint(content: content, fileURL: sampleFileURL, applyFixes: true).1
}

@Suite("Disable comments")
struct DisableDirectivesTests {
  // MARK: Ranges

  @Test func disablesEveryRuleUntilTheEnableComment() {
    let content = """
      bad ugly

      <!-- mdlint-disable -->

      bad ugly

      <!-- mdlint-enable -->

      bad ugly

      """

    #expect(reportedLines(in: content, of: bad) == [1, 9])
    #expect(reportedLines(in: content, of: ugly) == [1, 9])
  }

  @Test func disablesToTheEndOfTheFileWithoutAnEnableComment() {
    let content = "bad\n\n<!-- mdlint-disable -->\n\nbad\n\nbad\n"

    #expect(reportedLines(in: content) == [1])
  }

  @Test(arguments: [
    "<!-- mdlint-disable test.no-bad -->",
    "<!--mdlint-disable test.no-bad-->",
    "<!-- mdlint-disable test.no-bad, test.unrelated -->",
    "<!-- mdlint-disable test.unrelated,test.no-bad -->",
    "<!--\n  mdlint-disable\n  test.no-bad\n-->",
  ])
  func disablesOnlyTheNamedRules(comment: String) {
    let content = "\(comment)\n\nbad ugly\n"
    let line = content.split(separator: "\n", omittingEmptySubsequences: false).count - 1

    #expect(reportedLines(in: content, of: bad) == [])
    #expect(reportedLines(in: content, of: ugly) == [line])
  }

  @Test func enablesOnlyTheNamedRules() {
    let content = """
      <!-- mdlint-disable -->

      bad ugly

      <!-- mdlint-enable test.no-bad -->

      bad ugly

      """

    #expect(reportedLines(in: content, of: bad) == [7])
    #expect(reportedLines(in: content, of: ugly) == [])
  }

  @Test func enablingEveryRuleAlsoEndsANamedDisable() {
    let content = """
      <!-- mdlint-disable test.no-bad -->

      bad

      <!-- mdlint-enable -->

      bad

      """

    #expect(reportedLines(in: content) == [7])
  }

  @Test func disablingARuleTwiceNeedsOnlyOneEnable() {
    let content = """
      <!-- mdlint-disable test.no-bad -->
      <!-- mdlint-disable test.no-bad -->

      bad

      <!-- mdlint-enable test.no-bad -->

      bad

      """

    #expect(reportedLines(in: content) == [8])
  }

  // MARK: Single lines

  @Test func disablesOnlyTheNextLine() {
    let content = """
      bad
      <!-- mdlint-disable-next-line -->
      bad ugly
      bad ugly

      """

    #expect(reportedLines(in: content, of: bad) == [1, 4])
    #expect(reportedLines(in: content, of: ugly) == [4])
  }

  @Test func disablesOnlyTheNamedRulesOnTheNextLine() {
    let content = "<!-- mdlint-disable-next-line test.no-ugly -->\nbad ugly\nbad ugly\n"

    #expect(reportedLines(in: content, of: bad) == [2, 3])
    #expect(reportedLines(in: content, of: ugly) == [3])
  }

  @Test func nextLineCommentDoesNotEndAnEnclosingRange() {
    let content = """
      <!-- mdlint-disable test.no-bad -->
      <!-- mdlint-disable-next-line test.no-ugly -->
      bad ugly
      bad ugly

      """

    #expect(reportedLines(in: content, of: bad) == [])
    #expect(reportedLines(in: content, of: ugly) == [4])
  }

  // MARK: Where a comment takes effect

  @Test func commentInsideALineDecidesTheStateOfThatLine() {
    let content = """
      bad <!-- mdlint-disable --> bad
      bad
      bad <!-- mdlint-enable --> bad
      bad

      """

    #expect(reportedLines(in: content) == [3, 3, 4])
  }

  @Test func lastCommentOnALineWins() {
    let content = "bad <!-- mdlint-disable --> bad <!-- mdlint-enable -->\nbad\n"

    #expect(reportedLines(in: content) == [1, 1, 2])
  }

  @Test func commentTakesEffectOnTheLineWhereItEnds() {
    let content = """
      <!--
      mdlint-disable-next-line
      -->
      bad
      bad

      """

    #expect(reportedLines(in: content) == [5])
  }

  @Test func readsCommentsInsideOtherHTML() {
    let content = """
      <div>
      <!-- mdlint-disable -->
      </div>

      bad

      """

    #expect(reportedLines(in: content) == [])
  }

  @Test(arguments: [
    "- item\n\n  <!-- mdlint-disable-next-line -->\n  bad\n\n  bad\n",
    "> <!-- mdlint-disable-next-line -->\n> bad\n>\n> bad\n",
    "| a | b |\n| - | - |\n| <!-- mdlint-disable-next-line --> | x |\n| bad | x |\n| bad | x |\n",
  ])
  func readsCommentsInsideContainers(content: String) {
    let lines = reportedLines(in: content)

    #expect(lines.count == 1)
    #expect(
      lines.first == content.split(separator: "\n", omittingEmptySubsequences: false).count - 1)
  }

  @Test(arguments: ["\n", "\r\n", "\r"])
  func countsLinesWithEveryLineEnding(lineEnding: String) {
    let content = [
      "bad", "", "<!-- mdlint-disable -->", "", "bad", "", "<!--", "mdlint-enable", "-->", "",
      "<!-- mdlint-disable-next-line -->", "bad", "bad", "",
    ].joined(separator: lineEnding)

    #expect(reportedLines(in: content) == [1, 13])
  }

  // MARK: What is not a directive

  @Test(arguments: [
    "```\n<!-- mdlint-disable -->\n```\n\nbad\n",
    "    <!-- mdlint-disable -->\n\nbad\n",
    "`<!-- mdlint-disable -->`\n\nbad\n",
    "\\<!-- mdlint-disable -->\n\nbad\n",
    "<!-- mdlint-disabled -->\n\nbad\n",
    "<!-- Mdlint-Disable -->\n\nbad\n",
    "<!-- note: mdlint-disable -->\n\nbad\n",
  ])
  func ignoresTextThatIsNotADirective(content: String) {
    #expect(reportedLines(in: content).count == 1)
  }

  @Test func unknownRuleIdentifiersHaveNoEffect() {
    let content = "<!-- mdlint-disable test.does-not-exist -->\n\nbad ugly\n"

    #expect(reportedLines(in: content, of: bad) == [3])
    #expect(reportedLines(in: content, of: ugly) == [3])
  }

  // MARK: Automatic fixes

  @Test func fixLeavesDisabledRangesUnchanged() {
    let content = """
      bad ugly

      <!-- mdlint-disable -->

      bad ugly

      <!-- mdlint-enable -->

      bad ugly

      """
    let expected = """
      good nice

      <!-- mdlint-disable -->

      bad ugly

      <!-- mdlint-enable -->

      good nice

      """

    #expect(fixed(content) == expected)
  }

  @Test func fixAppliesTheRulesThatAreStillOn() {
    let content = """
      <!-- mdlint-disable test.no-bad -->

      bad ugly

      <!-- mdlint-enable -->
      <!-- mdlint-disable-next-line test.no-ugly -->
      bad ugly
      bad ugly

      """
    let expected = """
      <!-- mdlint-disable test.no-bad -->

      bad nice

      <!-- mdlint-enable -->
      <!-- mdlint-disable-next-line test.no-ugly -->
      good ugly
      good nice

      """

    #expect(fixed(content) == expected)
  }

  @Test(arguments: ["\n", "\r\n", "\r"])
  func fixKeepsLineEndings(lineEnding: String) {
    let content = ["bad", "<!-- mdlint-disable-next-line -->", "bad", "bad", ""]
      .joined(separator: lineEnding)
    let expected = ["good", "<!-- mdlint-disable-next-line -->", "bad", "good", ""]
      .joined(separator: lineEnding)

    #expect(fixed(content) == expected)
  }

  @Test func fixKeepsCodeNextToADisabledLine() {
    let content = """
      <!-- mdlint-disable-next-line -->
      bad `bad` bad
      bad `bad` bad

      """
    let expected = """
      <!-- mdlint-disable-next-line -->
      bad `bad` bad
      good `bad` good

      """

    #expect(fixed(content) == expected)
  }

  @Test func fixedFileReportsTheSameDisabledLines() throws {
    let content = "bad\n<!-- mdlint-disable-next-line -->\nbad\nbad\n"

    let result = try #require(fixed(content))

    // The lines that were left alone are still turned off, so nothing remains.
    #expect(reportedLines(in: result) == [])
  }

  @Test func appliesAFixThatChangesTheNumberOfLinesInAFileWithDirectives() {
    let rules: [Rule] = [BlankLineRule(), bad]
    let content = "bad\n\n\n<!-- mdlint-disable-next-line test.no-bad -->\nbad\n\nbad\n"

    // The comment moves up with the text, and it still covers the line after it.
    #expect(
      fixed(content, rules: rules)
        == "good\n<!-- mdlint-disable-next-line test.no-bad -->\nbad\ngood\n")
  }

  @Test func doesNotApplyALineRemovingFixOnDisabledLines() {
    let rules: [Rule] = [BlankLineRule(), bad]
    let content = """
      bad

      <!-- mdlint-disable test.no-blank-lines -->

      bad

      <!-- mdlint-enable -->

      bad

      """
    let expected = """
      good
      <!-- mdlint-disable test.no-blank-lines -->

      good

      <!-- mdlint-enable -->
      good

      """

    #expect(fixed(content, rules: rules) == expected)
  }
}

/// Reports every occurrence of a word and replaces it when fixing.
private struct WordRule: Rule {
  let id: String
  let word: String
  let replacement: String

  var description: String { "Replaces '\(word)' with '\(replacement)'" }

  func check(document _: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let lines = originalText.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    for (index, line) in lines.enumerated() {
      for range in line.ranges(of: word) {
        let column = line.distance(from: line.startIndex, to: range.lowerBound) + 1
        diagnostics.append(
          Diagnostic(
            file: fileURL,
            line: index + 1,
            column: column,
            ruleID: id,
            message: description,
            fixIt: FixIt(
              description: description, line: index + 1, column: column, endLine: index + 1,
              endColumn: column + word.count, replacement: replacement)))
      }
    }
    return diagnostics
  }
}

/// Reports blank lines and removes them when fixing, which changes the number of lines.
private struct BlankLineRule: Rule {
  let id = "test.no-blank-lines"
  let description = "Removes blank lines"

  func check(document _: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    let lines = originalText.split(separator: "\n", omittingEmptySubsequences: false)
    // The text after the last line break is not a line of its own.
    for (index, line) in lines.dropLast().enumerated() where line.isEmpty {
      diagnostics.append(
        Diagnostic(
          file: fileURL, line: index + 1, column: 1, ruleID: id, message: description,
          fixIt: FixIt(
            description: description, line: index + 1, column: 1, endLine: index + 2,
            endColumn: 1, replacement: "")))
    }
    return diagnostics
  }
}
