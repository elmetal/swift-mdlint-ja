import Testing

@testable import MDLintRules

@Suite("DefaultRules")
struct DefaultRulesTests {
  @Test func identifiersMatchTheRulesTheyCreate() {
    for identifier in DefaultRules.Identifier.allCases {
      #expect(identifier.makeRule(options: .init()).id == identifier.rawValue)
    }
  }

  @Test func allReturnsEveryRuleOnce() {
    let ids = DefaultRules.all().map(\.id)

    #expect(ids.count == DefaultRules.Identifier.allCases.count)
    #expect(Set(ids).count == ids.count)
  }
}
