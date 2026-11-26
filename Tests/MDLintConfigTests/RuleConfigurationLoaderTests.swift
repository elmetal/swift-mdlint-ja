import Foundation
import MDLintCore
import MDLintRules
import Markdown
import Testing

@testable import MDLintConfig

private let sampleFileURL = URL(fileURLWithPath: "/tmp/config-rule.md")

private let allRuleIDs = DefaultRules.Identifier.allCases.map(\.rawValue)

/// Writes `json` to a configuration file and returns its path.
private func makeConfigurationFile(_ json: String) throws -> String {
  let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
    UUID().uuidString)
  try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

  let fileURL = directoryURL.appendingPathComponent("config.json")
  try Data(json.utf8).write(to: fileURL)
  return fileURL.path
}

private func loadRules(
  _ json: String,
  politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle? = nil
) throws -> [Rule] {
  try RuleConfigurationLoader().loadRules(
    configurationPath: try makeConfigurationFile(json), politenessStyle: politenessStyle)
}

private func lint(_ content: String, with rules: [Rule]) -> [Diagnostic] {
  Linter(rules: rules).lint(content: content, fileURL: sampleFileURL, applyFixes: false).0
}

@Suite("RuleConfigurationLoader")
struct RuleConfigurationLoaderTests {
  @Test("returns all rules when configuration path is nil")
  func returnsAllRulesWhenConfigurationPathIsNil() throws {
    let loader = RuleConfigurationLoader()
    let rules = try loader.loadRules(configurationPath: nil)

    #expect(rules.map(\.id) == allRuleIDs)
  }

  @Test("throws when configuration file is missing")
  func throwsWhenConfigurationFileIsMissing() {
    let loader = RuleConfigurationLoader(fileManager: .default)

    #expect(throws: RuleConfigurationLoader.Error.fileNotFound("/path/to/missing.json")) {
      try loader.loadRules(configurationPath: "/path/to/missing.json")
    }
  }

  @Test("passes the politeness style to the rule without a configuration file")
  func passesPolitenessStyleWithoutConfigurationFile() throws {
    let rules = try RuleConfigurationLoader().loadRules(
      configurationPath: nil, politenessStyle: .dearu)

    #expect(lint("これはテストです。", with: rules).map(\.ruleID) == ["ja.style.no-mix-dearu-desumasu"])
  }

  @Test(
    "fails for a file that is not JSON",
    arguments: ["", "{", "[\"ja.period.prefer-fullwidth\"", "rules: {}"])
  func failsForFileThatIsNotJSON(json: String) {
    #expect(throws: DecodingError.self) { try loadRules(json) }
  }

  @Test(
    "fails for JSON that is neither an array nor an object",
    arguments: ["\"ja.period.prefer-fullwidth\"", "1", "true", "null"])
  func failsForOtherJSONValues(json: String) {
    #expect(
      throws: RuleConfigurationLoader.Error.invalidConfiguration(
        "expected an array of rule identifiers or an object with a \"rules\" key")
    ) { try loadRules(json) }
  }
}

@Suite("RuleConfigurationLoader: array of identifiers")
struct RuleConfigurationLoaderArrayTests {
  @Test("runs only the listed rules, in the listed order")
  func runsOnlyTheListedRules() throws {
    let rules = try loadRules(
      """
      ["ja.period.prefer-fullwidth", "ja.ellipsis.prefer-double"]
      """)

    #expect(rules.map(\.id) == ["ja.period.prefer-fullwidth", "ja.ellipsis.prefer-double"])
  }

  @Test("runs no rules for an empty array")
  func runsNoRulesForAnEmptyArray() throws {
    #expect(try loadRules("[]").isEmpty)
  }

  @Test("accepts the former names of renamed rules")
  func acceptsFormerNames() throws {
    let rules = try loadRules(
      """
      ["ja.comma.max-three", "ja.sentence.max-one-hundred-characters"]
      """)

    #expect(rules.map(\.id) == ["ja.comma.max-count", "ja.sentence.max-length"])
    // The limits are the ones the former names stood for.
    #expect(lint("一、二、三、四。", with: rules).isEmpty)
    #expect(lint("一、二、三、四、五。", with: rules).map(\.ruleID) == ["ja.comma.max-count"])
  }

  @Test("warns about unknown identifiers")
  func warnsAboutUnknownIdentifiers() throws {
    let path = try makeConfigurationFile(
      """
      ["ja.ellipsis.prefer-double", "unknown.rule", "another.unknown"]
      """)
    var warnedIdentifiers: [String] = []
    let loader = RuleConfigurationLoader(unknownIdentifierHandler: { identifiers in
      warnedIdentifiers = identifiers
    })

    let rules = try loader.loadRules(configurationPath: path)

    #expect(rules.map(\.id) == ["ja.ellipsis.prefer-double"])
    #expect(warnedIdentifiers == ["unknown.rule", "another.unknown"])
  }

  @Test("applies the politeness style given by the caller")
  func appliesPolitenessStyle() throws {
    let rules = try loadRules(
      """
      ["ja.style.no-mix-dearu-desumasu"]
      """, politenessStyle: .dearu)

    #expect(lint("これはテストです。", with: rules).count == 1)
  }

  @Test("fails when an element is not a string", arguments: ["[1]", "[\"a\", {}]", "[null]"])
  func failsWhenAnElementIsNotAString(json: String) {
    #expect(
      throws: RuleConfigurationLoader.Error.invalidConfiguration(
        "the rule identifiers in the array must be strings")
    ) { try loadRules(json) }
  }
}

@Suite("RuleConfigurationLoader: object with rules")
struct RuleConfigurationLoaderObjectTests {
  // MARK: Choosing the rules

  @Test(
    "keeps every default rule that is not mentioned",
    arguments: ["{}", "{\"rules\": {}}", "{\"rules\": {\"ja.kana.no-halfwidth\": true}}"])
  func keepsDefaultRules(json: String) throws {
    #expect(try loadRules(json).map(\.id) == allRuleIDs)
  }

  @Test("turns off the rules set to false")
  func turnsOffRulesSetToFalse() throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.kana.no-halfwidth": false, "ja.comma.max-count": false}}
      """)

    #expect(
      rules.map(\.id)
        == allRuleIDs.filter { $0 != "ja.kana.no-halfwidth" && $0 != "ja.comma.max-count" })
  }

  @Test("keeps a rule on when it has an empty object of options")
  func keepsRuleWithEmptyOptions() throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.kana.no-halfwidth": {}}}
      """)

    #expect(rules.map(\.id) == allRuleIDs)
  }

  // MARK: Options

  @Test("sets the comma limit")
  func setsCommaLimit() throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.comma.max-count": {"max": 1}}}
      """)

    let diagnostics = lint("一、二、三。", with: rules).filter { $0.ruleID == "ja.comma.max-count" }
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.message.contains("2つ以上") == true)
  }

  @Test("sets the sentence length limit")
  func setsSentenceLengthLimit() throws {
    let content = String(repeating: "あ", count: 110) + "。"

    let relaxed = try loadRules(
      """
      {"rules": {"ja.sentence.max-length": {"max": 120}}}
      """)
    let tightened = try loadRules(
      """
      {"rules": {"ja.sentence.max-length": {"max": 20}}}
      """)

    #expect(lint(content, with: relaxed).isEmpty)
    #expect(lint(content, with: tightened).map(\.column) == [21])
  }

  @Test("accepts options under the former name of a rule")
  func acceptsOptionsUnderFormerName() throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.comma.max-three": {"max": 1, "severity": "error"}}}
      """)

    let diagnostics = lint("一、二、三。", with: rules).filter { $0.ruleID == "ja.comma.max-count" }
    #expect(diagnostics.map(\.severity) == [.error])
  }

  @Test("sets the politeness style")
  func setsPolitenessStyle() throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.style.no-mix-dearu-desumasu": {"style": "dearu"}}}
      """)

    #expect(lint("これはテストです。", with: rules).map(\.ruleID) == ["ja.style.no-mix-dearu-desumasu"])
    #expect(lint("これはテストである。", with: rules).isEmpty)
  }

  @Test("prefers the politeness style given by the caller over the file")
  func prefersCallerPolitenessStyle() throws {
    let json = """
      {"rules": {"ja.style.no-mix-dearu-desumasu": {"style": "dearu"}}}
      """

    let rules = try loadRules(json, politenessStyle: .desumasu)

    #expect(lint("これはテストです。", with: rules).isEmpty)
    #expect(lint("これはテストである。", with: rules).count == 1)
  }

  // MARK: Severity

  @Test(
    "reports a rule with the configured severity",
    arguments: [
      ("info", Diagnostic.Severity.info), ("warning", .warning), ("error", .error),
    ])
  func reportsConfiguredSeverity(name: String, severity: Diagnostic.Severity) throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.period.prefer-fullwidth": {"severity": "\(name)"}}}
      """)

    let diagnostics = lint("これは Test です.", with: rules)

    #expect(diagnostics.count == 3)
    for diagnostic in diagnostics {
      let expected = diagnostic.ruleID == "ja.period.prefer-fullwidth" ? severity : .warning
      #expect(diagnostic.severity == expected)
    }
  }

  @Test("keeps everything else about the diagnostics of a rule with a severity")
  func keepsDiagnosticsOtherwiseUnchanged() throws {
    let content = "これは Test です.\n\n終わり.\n"
    let configured = try loadRules(
      """
      {"rules": {"ja.period.prefer-fullwidth": {"severity": "error"}}}
      """)
    let defaults = try RuleConfigurationLoader().loadRules(configurationPath: nil)

    func locations(_ diagnostics: [Diagnostic]) -> [String] {
      diagnostics.map {
        "\($0.line):\($0.column) \($0.ruleID) \($0.message) \($0.fixIt?.description ?? "")"
      }
    }

    #expect(locations(lint(content, with: configured)) == locations(lint(content, with: defaults)))
  }

  @Test("still fixes a rule that has a severity")
  func stillFixesRuleWithSeverity() throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.period.prefer-fullwidth": {"severity": "error"}}}
      """)

    let fixed = Linter(rules: rules)
      .lint(content: "これは Test です.\n", fileURL: sampleFileURL, applyFixes: true).1

    #expect(fixed == "これはTestです。\n")
  }

  @Test("lets a comment turn off a rule that has options and a severity")
  func commentTurnsOffConfiguredRule() throws {
    let rules = try loadRules(
      """
      {"rules": {"ja.comma.max-count": {"max": 1, "severity": "error"}}}
      """)
    let content = """
      一、二、三。

      <!-- mdlint-disable-next-line ja.comma.max-count -->
      一、二、三。

      """

    #expect(lint(content, with: rules).map(\.line) == [1])
  }

  // MARK: Unknown names

  @Test("warns about unknown identifiers and runs the rest")
  func warnsAboutUnknownIdentifiers() throws {
    let path = try makeConfigurationFile(
      """
      {"rules": {"zz.unknown": {"max": "x"}, "ja.kana.no-halfwidth": false, "aa.unknown": true}}
      """)
    var warnedIdentifiers: [String] = []
    let loader = RuleConfigurationLoader(unknownIdentifierHandler: { warnedIdentifiers = $0 })

    let rules = try loader.loadRules(configurationPath: path)

    #expect(rules.map(\.id) == allRuleIDs.filter { $0 != "ja.kana.no-halfwidth" })
    #expect(warnedIdentifiers == ["aa.unknown", "zz.unknown"])
  }

  @Test("warns about options a rule does not accept and applies the others")
  func warnsAboutUnknownOptions() throws {
    let path = try makeConfigurationFile(
      """
      {
        "rules": {
          "ja.comma.max-count": {"max": 1, "style": "dearu", "limit": 2},
          "ja.kana.no-halfwidth": {"max": 3}
        }
      }
      """)
    var warnings: [String: [String]] = [:]
    let loader = RuleConfigurationLoader(unknownOptionHandler: { warnings[$0] = $1 })

    let rules = try loader.loadRules(configurationPath: path)

    #expect(
      warnings == ["ja.comma.max-count": ["limit", "style"], "ja.kana.no-halfwidth": ["max"]])
    #expect(lint("一、二、三。", with: rules).map(\.ruleID) == ["ja.comma.max-count"])
  }

  // MARK: Invalid input

  @Test(
    "fails for an invalid configuration",
    arguments: [
      (
        "{\"rule\": {}}",
        "unknown key \"rule\"; the supported keys are \"rules\" and \"exclude\""
      ),
      (
        "{\"rules\": {}, \"ignore\": []}",
        "unknown key \"ignore\"; the supported keys are \"rules\" and \"exclude\""
      ),
      (
        "{\"rules\": [\"ja.kana.no-halfwidth\"]}",
        "\"rules\" must be an object keyed by rule identifier"
      ),
      (
        "{\"rules\": {\"ja.kana.no-halfwidth\": \"off\"}}",
        "\"ja.kana.no-halfwidth\" must be true, false, or an object of options"
      ),
      (
        "{\"rules\": {\"ja.kana.no-halfwidth\": null}}",
        "\"ja.kana.no-halfwidth\" must be true, false, or an object of options"
      ),
      (
        "{\"rules\": {\"ja.kana.no-halfwidth\": 1}}",
        "\"ja.kana.no-halfwidth\" must be true, false, or an object of options"
      ),
      (
        "{\"rules\": {\"ja.comma.max-three\": true, \"ja.comma.max-count\": {\"max\": 2}}}",
        "\"ja.comma.max-count\" and \"ja.comma.max-three\" name the same rule; keep only one of them"
      ),
    ])
  func failsForInvalidConfiguration(json: String, reason: String) {
    #expect(throws: RuleConfigurationLoader.Error.invalidConfiguration(reason)) {
      try loadRules(json)
    }
  }

  @Test(
    "fails for a limit that is not a positive integer",
    arguments: ["0", "-1", "1.5", "\"5\"", "true", "null", "[5]", "{}"])
  func failsForInvalidLimit(value: String) {
    for rule in ["ja.comma.max-count", "ja.sentence.max-length", "ja.comma.max-three"] {
      #expect(
        throws: RuleConfigurationLoader.Error.invalidConfiguration(
          "\"max\" of \"\(rule)\" must be an integer of 1 or more")
      ) { try loadRules("{\"rules\": {\"\(rule)\": {\"max\": \(value)}}}") }
    }
  }

  @Test(
    "fails for an unknown severity",
    arguments: ["\"fatal\"", "\"Error\"", "\"\"", "2", "true", "null"])
  func failsForInvalidSeverity(value: String) {
    #expect(
      throws: RuleConfigurationLoader.Error.invalidConfiguration(
        "\"severity\" of \"ja.kana.no-halfwidth\" must be \"info\", \"warning\", or \"error\"")
    ) { try loadRules("{\"rules\": {\"ja.kana.no-halfwidth\": {\"severity\": \(value)}}}") }
  }

  @Test("fails for an unknown politeness style", arguments: ["\"polite\"", "\"\"", "1", "null"])
  func failsForInvalidStyle(value: String) {
    #expect(
      throws: RuleConfigurationLoader.Error.invalidConfiguration(
        "\"style\" of \"ja.style.no-mix-dearu-desumasu\" must be \"auto\", \"desumasu\", or \"dearu\""
      )
    ) {
      try loadRules("{\"rules\": {\"ja.style.no-mix-dearu-desumasu\": {\"style\": \(value)}}}")
    }
  }
}

@Suite("RuleConfigurationLoader: excluded files")
struct RuleConfigurationLoaderExcludeTests {
  @Test("reads the patterns and makes them relative to the directory of the file")
  func readsExcludePatterns() throws {
    let path = try makeConfigurationFile(
      """
      {"exclude": ["vendor/**", "CHANGELOG.md", "**/draft-?.md"]}
      """)
    let directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()

    let configuration = try RuleConfigurationLoader().loadConfiguration(configurationPath: path)

    #expect(
      configuration.excludePatterns.map(\.description)
        == ["vendor/**", "CHANGELOG.md", "**/draft-?.md"])
    #expect(configuration.directoryURL?.standardizedFileURL == directoryURL.standardizedFileURL)
    #expect(configuration.excludes(directoryURL.appendingPathComponent("vendor/lib/README.md")))
    #expect(configuration.excludes(directoryURL.appendingPathComponent("CHANGELOG.md")))
    #expect(configuration.excludes(directoryURL.appendingPathComponent("docs/draft-1.md")))
    #expect(!configuration.excludes(directoryURL.appendingPathComponent("docs/CHANGELOG.md")))
    #expect(!configuration.excludes(directoryURL.appendingPathComponent("README.md")))
  }

  @Test("keeps every default rule when only exclude is given")
  func keepsDefaultRulesWithExcludeOnly() throws {
    #expect(try loadRules("{\"exclude\": [\"vendor\"]}").map(\.id) == allRuleIDs)
  }

  @Test("applies rules and exclude from the same file")
  func appliesRulesAndExclude() throws {
    let path = try makeConfigurationFile(
      """
      {"rules": {"ja.kana.no-halfwidth": false}, "exclude": ["vendor"]}
      """)

    let configuration = try RuleConfigurationLoader().loadConfiguration(configurationPath: path)

    #expect(configuration.rules.map(\.id) == allRuleIDs.filter { $0 != "ja.kana.no-halfwidth" })
    #expect(configuration.excludePatterns.map(\.description) == ["vendor"])
  }

  @Test(
    "excludes nothing when the file does not say so",
    arguments: ["{}", "{\"exclude\": []}", "{\"rules\": {}}", "[\"ja.kana.no-halfwidth\"]"])
  func excludesNothingByDefault(json: String) throws {
    let path = try makeConfigurationFile(json)

    let configuration = try RuleConfigurationLoader().loadConfiguration(configurationPath: path)

    #expect(configuration.excludePatterns.isEmpty)
    #expect(!configuration.excludes(URL(fileURLWithPath: path)))
  }

  @Test("excludes nothing without a configuration file")
  func excludesNothingWithoutFile() throws {
    let configuration = try RuleConfigurationLoader().loadConfiguration(configurationPath: nil)

    #expect(configuration.rules.map(\.id) == allRuleIDs)
    #expect(configuration.excludePatterns.isEmpty)
    #expect(configuration.directoryURL == nil)
  }

  @Test(
    "fails when exclude is not an array of strings",
    arguments: [
      "\"vendor/**\"", "{}", "null", "true", "1", "[1]", "[\"vendor\", null]", "[[\"vendor\"]]",
    ])
  func failsForWrongType(value: String) {
    #expect(
      throws: RuleConfigurationLoader.Error.invalidConfiguration(
        "\"exclude\" must be an array of path patterns")
    ) { try loadRules("{\"exclude\": \(value)}") }
  }

  @Test(
    "fails for a pattern that is empty, absolute, or leaves the directory",
    arguments: ["", "/vendor/**", "../vendor", "docs/../../vendor", "./"])
  func failsForInvalidPattern(pattern: String) {
    #expect(
      throws: RuleConfigurationLoader.Error.invalidConfiguration(
        "the \"exclude\" pattern \"\(pattern)\" must be a path relative to the configuration file"
          + " that is not empty and has no \"..\"")
    ) { try loadRules("{\"exclude\": [\"vendor\", \"\(pattern)\"]}") }
  }

  @Test("still rejects other top-level keys next to exclude")
  func rejectsOtherKeys() {
    #expect(
      throws: RuleConfigurationLoader.Error.invalidConfiguration(
        "unknown key \"excludes\"; the supported keys are \"rules\" and \"exclude\"")
    ) { try loadRules("{\"exclude\": [], \"excludes\": []}") }
  }
}

@Suite("RuleConfigurationLoader: finding the configuration file")
struct RuleConfigurationLoaderDiscoveryTests {
  /// Creates a directory tree with the given directories and returns its root.
  private func makeTree(directories: [String], files: [String] = []) throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("mdlint-ja-discovery-\(UUID().uuidString)")
    for directory in directories {
      try FileManager.default.createDirectory(
        at: root.appendingPathComponent(directory), withIntermediateDirectories: true)
    }
    for file in files {
      try Data("{}".utf8).write(to: root.appendingPathComponent(file))
    }
    return root
  }

  private func standardizedPath(_ url: URL) -> String { url.standardizedFileURL.path }

  @Test("finds the file in the directory itself")
  func findsFileInDirectory() throws {
    let root = try makeTree(directories: ["docs"], files: [".mdlint.json"])
    defer { try? FileManager.default.removeItem(at: root) }

    let found = RuleConfigurationLoader().findConfigurationFile(from: root)

    #expect(found == standardizedPath(root.appendingPathComponent(".mdlint.json")))
  }

  @Test("finds the file in a parent directory")
  func findsFileInParentDirectory() throws {
    let root = try makeTree(directories: ["docs/guide/ja"], files: [".mdlint.json"])
    defer { try? FileManager.default.removeItem(at: root) }

    let found = RuleConfigurationLoader().findConfigurationFile(
      from: root.appendingPathComponent("docs/guide/ja"))

    #expect(found == standardizedPath(root.appendingPathComponent(".mdlint.json")))
  }

  @Test("prefers the nearest file")
  func prefersNearestFile() throws {
    let root = try makeTree(
      directories: ["docs/guide/ja"], files: [".mdlint.json", "docs/.mdlint.json"])
    defer { try? FileManager.default.removeItem(at: root) }
    let loader = RuleConfigurationLoader()

    let nested = standardizedPath(root.appendingPathComponent("docs/.mdlint.json"))
    #expect(loader.findConfigurationFile(from: root.appendingPathComponent("docs/guide")) == nested)
    #expect(loader.findConfigurationFile(from: root.appendingPathComponent("docs")) == nested)
    #expect(
      loader.findConfigurationFile(from: root)
        == standardizedPath(root.appendingPathComponent(".mdlint.json")))
  }

  @Test("does not look into subdirectories or at files with other names")
  func ignoresSubdirectoriesAndOtherNames() throws {
    let root = try makeTree(
      directories: ["docs"], files: ["docs/.mdlint.json", "mdlint.json", ".mdlint.jsonc"])
    defer { try? FileManager.default.removeItem(at: root) }

    let found = RuleConfigurationLoader().findConfigurationFile(from: root)

    // A file further up, outside the tree, would still be found.
    #expect(found?.hasPrefix(standardizedPath(root) + "/") != true)
  }

  @Test("passes over a directory that has the name of the file")
  func passesOverDirectoryWithTheName() throws {
    let root = try makeTree(directories: ["docs/.mdlint.json"], files: [".mdlint.json"])
    defer { try? FileManager.default.removeItem(at: root) }

    let found = RuleConfigurationLoader().findConfigurationFile(
      from: root.appendingPathComponent("docs"))

    #expect(found == standardizedPath(root.appendingPathComponent(".mdlint.json")))
  }
}
