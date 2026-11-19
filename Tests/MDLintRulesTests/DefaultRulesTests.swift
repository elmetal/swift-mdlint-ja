import Testing

@testable import MDLintRules

@Suite("DefaultRules")
struct DefaultRulesTests {
  @Test func identifiersMatchTheRulesTheyCreate() {
    for identifier in DefaultRules.Identifier.allCases {
      #expect(identifier.makeRule(options: .init()).id == identifier.rawValue)
    }
  }

  @Test func optionsReachTheRulesThatAcceptThem() {
    let options = DefaultRules.Options(maxCommaCount: 1, maxSentenceLength: 5)
    let commaRule = DefaultRules.Identifier.japaneseCommaLimit.makeRule(options: options)
    let lengthRule = DefaultRules.Identifier.sentenceLengthLimit.makeRule(options: options)

    #expect(commaRule.diagnostics(for: "一、二、三。").count == 1)
    #expect(lengthRule.diagnostics(for: "あいうえおか。").count == 1)
  }

  @Test(arguments: [
    ("ja.comma.max-count", DefaultRules.Identifier.japaneseCommaLimit),
    ("ja.comma.max-three", .japaneseCommaLimit),
    ("ja.sentence.max-length", .sentenceLengthLimit),
    ("ja.sentence.max-one-hundred-characters", .sentenceLengthLimit),
    ("ja.period.prefer-fullwidth", .japanesePeriod),
  ])
  func resolvesCurrentAndFormerNames(name: String, expected: DefaultRules.Identifier) {
    #expect(DefaultRules.Identifier(name: name) == expected)
  }

  @Test func doesNotResolveUnknownNames() {
    #expect(DefaultRules.Identifier(name: "ja.comma.max-four") == nil)
  }

  @Test func formerNamesAreNotCurrentNames() {
    for name in DefaultRules.Identifier.formerNames.keys {
      #expect(DefaultRules.Identifier(rawValue: name) == nil)
    }
  }

  @Test func allReturnsEveryRuleOnce() {
    let ids = DefaultRules.all().map(\.id)

    #expect(ids.count == DefaultRules.Identifier.allCases.count)
    #expect(Set(ids).count == ids.count)
  }
}
