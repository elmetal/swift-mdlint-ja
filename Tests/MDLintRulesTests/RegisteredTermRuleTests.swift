import Foundation
import MDLintCore
import Markdown
import Testing

@testable import MDLintRules

private typealias Term = RegisteredTermRule.Term

private let serverAndUser = [
  Term(expected: "サーバー", variants: ["サーバ"]),
  Term(expected: "ユーザー", variants: ["ユーザ", "ユーザ-"]),
]

@Suite("RegisteredTermRule")
struct RegisteredTermRuleTests {
  // MARK: Matching

  @Test func reportsNothingWithoutTerms() {
    let content = "サーバを起動し、ユーザが接続する。"

    #expect(RegisteredTermRule().diagnostics(for: content).isEmpty)
    #expect(RegisteredTermRule(terms: []).fixed(content) == content)
  }

  @Test func reportsNothingForTermsWithoutVariants() {
    let rule = RegisteredTermRule(terms: [Term(expected: "サーバー")])

    #expect(rule.diagnostics(for: "サーバとサーバー").isEmpty)
  }

  @Test func reportsEveryVariantWhereItIs() {
    let rule = RegisteredTermRule(terms: serverAndUser)

    let diagnostics = rule.diagnostics(for: "サーバを起動し、ユーザがサーバに接続する。\n\nユーザを追加する。\n")

    #expect(diagnostics.map(\.line) == [1, 1, 1, 3])
    #expect(diagnostics.map(\.column) == [1, 9, 13, 1])
    #expect(diagnostics.allSatisfy { $0.ruleID == "ja.term.prefer-registered" })
    #expect(diagnostics.allSatisfy { $0.severity == .warning })
    #expect(diagnostics.first?.message == "「サーバ」は「サーバー」と表記してください。")
  }

  @Test func attachesAFixItThatReplacesTheVariant() {
    let rule = RegisteredTermRule(terms: serverAndUser)

    let diagnostics = rule.diagnostics(for: "まずユーザを追加する。")

    #expect(
      diagnostics.map(\.fixIt) == [
        FixIt(
          description: "「ユーザ」を「ユーザー」に置換", line: 1, column: 3, endLine: 1, endColumn: 6,
          replacement: "ユーザー")
      ])
  }

  @Test func fixesEveryVariant() {
    let rule = RegisteredTermRule(terms: serverAndUser)

    #expect(
      rule.fixed("サーバを起動し、ユーザがサーバに接続する。\r\nユーザを追加する。\n")
        == "サーバーを起動し、ユーザーがサーバーに接続する。\r\nユーザーを追加する。\n")
  }

  @Test func comparesSpellingsCaseSensitively() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "GitHub", variants: ["Github", "github"])
    ])
    let content = "Github と github と GitHub と GITHUB"

    #expect(rule.diagnostics(for: content).map(\.column) == [1, 10])
    #expect(rule.fixed(content) == "GitHub と GitHub と GitHub と GITHUB")
  }

  @Test func matchesCanonicallyEquivalentText() {
    // "バ" written as "ハ" and a combining voiced sound mark is one character.
    let rule = RegisteredTermRule(terms: serverAndUser)
    let content = "サーハ\u{3099}を起動する。"

    #expect(rule.diagnostics(for: content).map(\.fixIt?.endColumn) == [4])
    #expect(rule.fixed(content) == "サーバーを起動する。")
  }

  // MARK: The expected spelling in the text

  @Test func doesNotReportAVariantThatStartsItsExpectedSpelling() {
    let rule = RegisteredTermRule(terms: serverAndUser)
    let content = "サーバーを起動し、ユーザーが接続する。"

    #expect(rule.diagnostics(for: content).isEmpty)
    #expect(rule.fixed(content) == content)
  }

  @Test func doesNotReportAVariantInsideItsExpectedSpelling() {
    let rule = RegisteredTermRule(terms: [Term(expected: "お問い合わせ", variants: ["問い合わせ"])])
    let content = "お問い合わせはこちら。問い合わせの前に、お問い合わせ履歴を確認する。"

    #expect(rule.diagnostics(for: content).map(\.column) == [12])
    #expect(rule.fixed(content) == "お問い合わせはこちら。お問い合わせの前に、お問い合わせ履歴を確認する。")
  }

  @Test func doesNotReportAVariantInsideItsExpectedSpellingAfterAnotherMatch() {
    // "Aお" is taken first, so the scan never starts at "お問い合わせ".
    let rule = RegisteredTermRule(terms: [
      Term(expected: "Z", variants: ["Aお"]),
      Term(expected: "お問い合わせ", variants: ["問い合わせ"]),
    ])

    #expect(rule.diagnostics(for: "Aお問い合わせ").map(\.column) == [1])
  }

  @Test func replacesALongerVariantWithAShorterExpectedSpelling() {
    let rule = RegisteredTermRule(terms: [Term(expected: "サーバ", variants: ["サーバー"])])
    let content = "サーバーとサーバ"

    #expect(rule.diagnostics(for: content).map(\.column) == [1])
    #expect(rule.fixed(content) == "サーバとサーバ")
  }

  // MARK: Overlapping terms

  @Test func prefersTheLongestVariantThatStartsAtACharacter() {
    let rule = RegisteredTermRule(terms: serverAndUser)
    let content = "ユーザ-がログインする。"

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.map(\.fixIt?.endColumn) == [5])
    #expect(rule.fixed(content) == "ユーザーがログインする。")
  }

  @Test func prefersTheLongestSpellingAcrossTerms() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "サーバー", variants: ["サーバ"]),
      Term(expected: "サーバーサイド", variants: ["サーバサイド"]),
    ])
    let content = "サーバサイドとサーバーサイドとサーバ"

    #expect(rule.diagnostics(for: content).map(\.column) == [1, 16])
    #expect(rule.fixed(content) == "サーバーサイドとサーバーサイドとサーバー")
  }

  @Test func aLongerExpectedSpellingProtectsAWordFromAShorterVariant() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "ユーザー", variants: ["ユーザ"]),
      Term(expected: "ユーザビリティ"),
    ])
    let content = "ユーザビリティをユーザが評価する。"

    #expect(rule.diagnostics(for: content).map(\.column) == [9])
    #expect(rule.fixed(content) == "ユーザビリティをユーザーが評価する。")
  }

  @Test func prefersTheSpellingThatStartsFirst() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "X", variants: ["AB"]),
      Term(expected: "Y", variants: ["BC"]),
    ])

    #expect(rule.diagnostics(for: "ABC").map(\.column) == [1])
    #expect(rule.fixed("ABC") == "XC")
    #expect(rule.fixed("BC") == "Y")
  }

  // MARK: Code and link targets

  @Test func leavesCodeSpansNextToProseAlone() {
    let rule = RegisteredTermRule(terms: serverAndUser)
    let content = "サーバ`サーバ`サーバと`ユーザ`"

    #expect(rule.diagnostics(for: content).map(\.column) == [1, 9])
    #expect(rule.fixed(content) == "サーバー`サーバ`サーバーと`ユーザ`")
  }

  @Test func doesNotMatchAcrossACodeSpan() {
    let rule = RegisteredTermRule(terms: [Term(expected: "サーバー", variants: ["サ`ー`バ", "サバ"])])
    let content = "サ`ー`バ"

    #expect(rule.diagnostics(for: content).isEmpty)
    #expect(rule.fixed(content) == content)
  }

  @Test func leavesCodeBlocksAndRawHTMLAlone() {
    let rule = RegisteredTermRule(terms: serverAndUser)
    let content = "サーバの例:\n\n```sh\nサーバ --ユーザ admin\n```\n\n<div>サーバ</div>\n\n    ユーザ\n"

    #expect(rule.diagnostics(for: content).map(\.line) == [1])
    #expect(
      rule.fixed(content) == "サーバーの例:\n\n```sh\nサーバ --ユーザ admin\n```\n\n<div>サーバ</div>\n\n    ユーザ\n"
    )
  }

  @Test func leavesLinkAndImageDestinationsAlone() {
    let rule = RegisteredTermRule(terms: serverAndUser)
    let content = "[サーバの設定](./サーバ(1).md)と![ユーザ](ユーザ.png \"ユーザ\")とサーバ"

    #expect(rule.diagnostics(for: content).map(\.column) == [2, 25, 45])
    #expect(rule.fixed(content) == "[サーバーの設定](./サーバ(1).md)と![ユーザー](ユーザ.png \"ユーザ\")とサーバー")
  }

  @Test func leavesURLsAlone() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "GitHub", variants: ["github"]),
      Term(expected: "サーバー", variants: ["サーバ"]),
    ])
    let content = "github は https://github.com/サーバ と <https://example.com/github> にある。"

    #expect(rule.diagnostics(for: content).map(\.column) == [1])
    #expect(
      rule.fixed(content) == "GitHub は https://github.com/サーバ と <https://example.com/github> にある。")
  }

  @Test func leavesLinkReferenceDefinitionsAloneButNotFootnotes() {
    let rule = RegisteredTermRule(terms: serverAndUser)
    let content = "[設定][docs]を読む。\n\n[docs]: ./サーバ.md\n\n[^1]: サーバの説明\n"

    let diagnostics = rule.diagnostics(for: content)

    #expect(diagnostics.map(\.line) == [5])
    #expect(diagnostics.map(\.column) == [7])
  }

  // MARK: Terms that were not validated

  @Test func neverReportsASpellingThatIsExpectedSomewhere() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "サーバー", variants: ["サーバ"]),
      Term(expected: "サーバ", variants: ["サーバー"]),
    ])

    #expect(rule.diagnostics(for: "サーバとサーバー").isEmpty)
  }

  @Test func givesAVariantToTheFirstTermThatListsIt() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "サーバー", variants: ["鯖"]),
      Term(expected: "さば", variants: ["鯖"]),
    ])

    #expect(rule.fixed("鯖") == "サーバー")
  }

  @Test func skipsSpellingsThatCannotBeUsed() {
    let rule = RegisteredTermRule(terms: [
      Term(expected: "サーバー", variants: ["", "サー\nバ", "\u{FFFC}", "サーバ"]),
      Term(expected: "", variants: ["ユーザ"]),
    ])
    let content = "サーバと`a`と\n\nサー\nバとユーザ\n"

    #expect(rule.diagnostics(for: content).map(\.column) == [1])
    #expect(rule.fixed(content) == "サーバーと`a`と\n\nサー\nバとユーザ\n")
  }
}

@Suite("RegisteredTermRule.validate")
struct RegisteredTermValidationTests {
  private typealias TermError = RegisteredTermRule.TermError

  @Test func acceptsTermsThatDoNotContradictEachOther() throws {
    try RegisteredTermRule.validate([])
    try RegisteredTermRule.validate(serverAndUser)
    try RegisteredTermRule.validate([
      Term(expected: "ユーザビリティ"),
      Term(expected: "サーバー", variants: ["サーバ", "サーバ"]),
      Term(expected: "サーバー", variants: ["サーバ", "鯖"]),
      Term(expected: "サーバーサイド", variants: ["サーバサイド"]),
    ])
  }

  @Test(arguments: ["", "サー\nバ", "サー\r\nバ", "サ\u{FFFC}バ", "\u{E000}"])
  func rejectsSpellingsThatCannotBeUsed(spelling: String) {
    #expect(throws: TermError.unusableSpelling(spelling, termIndex: 1)) {
      try RegisteredTermRule.validate([
        Term(expected: "サーバー", variants: ["サーバ"]),
        Term(expected: "ユーザー", variants: ["ユーザ", spelling]),
      ])
    }
    #expect(throws: TermError.unusableSpelling(spelling, termIndex: 0)) {
      try RegisteredTermRule.validate([Term(expected: spelling, variants: ["サーバ"])])
    }
  }

  @Test func rejectsASpellingThatIsExpectedAndVariant() {
    #expect(throws: TermError.expectedAndVariant("サーバー")) {
      try RegisteredTermRule.validate([Term(expected: "サーバー", variants: ["サーバ", "サーバー"])])
    }
    #expect(throws: TermError.expectedAndVariant("サーバ")) {
      try RegisteredTermRule.validate([
        Term(expected: "サーバー", variants: ["サーバ"]),
        Term(expected: "サーバ", variants: ["鯖"]),
      ])
    }
  }

  @Test func rejectsAVariantOfSeveralTerms() {
    #expect(throws: TermError.variantOfSeveralTerms("鯖", expected: ["サーバー", "さば"])) {
      try RegisteredTermRule.validate([
        Term(expected: "サーバー", variants: ["鯖"]),
        Term(expected: "さば", variants: ["鯖"]),
      ])
    }
  }

  @Test func comparesSpellingsByCanonicalEquivalence() {
    #expect(throws: TermError.expectedAndVariant("サーハ\u{3099}")) {
      try RegisteredTermRule.validate([
        Term(expected: "サーバ", variants: ["鯖"]),
        Term(expected: "サーバー", variants: ["サーハ\u{3099}"]),
      ])
    }
  }
}

@Suite("Fixing registered terms with every rule")
struct RegisteredTermFixingTests {
  private let rules = DefaultRules.all(options: .init(terms: serverAndUser))

  private func lint(_ content: String, applyFixes: Bool) -> ([Diagnostic], String?) {
    Linter(rules: rules).lint(content: content, fileURL: sampleFileURL, applyFixes: applyFixes)
  }

  @Test func oneRunFixesEverythingAndLeavesCodeAlone() throws {
    let content = """
      # サーバ構成.

      ユーザは `サーバ --ユーザ admin` でサーバを起動します。ユーザ-ごとの設定は[サーバ設定](./サーバ.md)にあります.

      ```sh
      サーバ --ユーザ admin
      ```

      サーバーとユーザーはそのままです。
      """

    let (diagnostics, fixed) = lint(content, applyFixes: true)

    let termDiagnostics = diagnostics.filter { $0.ruleID == "ja.term.prefer-registered" }
    #expect(termDiagnostics.map(\.line) == [1, 3, 3, 3, 3])
    #expect(
      fixed == """
        # サーバー構成

        ユーザーは `サーバ --ユーザ admin` でサーバーを起動します。ユーザーごとの設定は[サーバー設定](./サーバ.md)にあります。

        ```sh
        サーバ --ユーザ admin
        ```

        サーバーとユーザーはそのままです。
        """)

    let once = try #require(fixed)
    let (remaining, again) = lint(once, applyFixes: true)
    #expect(remaining.isEmpty)
    #expect(again == once)
  }
}
