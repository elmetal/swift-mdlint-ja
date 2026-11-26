import Foundation
import MDLintCore
import MDLintRules
import Markdown

/// Loads lint rules from a JSON configuration file.
///
/// The file takes one of two forms.
///
/// An array lists the identifiers of the rules to run. Every rule runs with
/// its default settings:
///
/// ```json
/// ["ja.period.prefer-fullwidth", "ja.comma.max-count"]
/// ```
///
/// An object adjusts the default rule set. Each entry of `rules` names a rule
/// and gives `false` to turn it off, `true` to run it as it is, or an object
/// of options. Rules that are not named keep running with their defaults:
///
/// ```json
/// {
///   "rules": {
///     "ja.sentence.max-length": { "max": 120 },
///     "ja.comma.max-count": { "severity": "error" },
///     "ja.kana.no-halfwidth": false
///   }
/// }
/// ```
///
/// Every rule accepts `severity` (`info`, `warning`, or `error`).
/// `ja.comma.max-count` and `ja.sentence.max-length` accept `max`,
/// `ja.style.no-mix-dearu-desumasu` accepts `style` (`auto`, `desumasu`, or
/// `dearu`), and `ja.term.prefer-registered` accepts `terms`, the terms whose
/// variants it replaces:
///
/// ```json
/// {
///   "rules": {
///     "ja.term.prefer-registered": {
///       "terms": [
///         { "expected": "サーバー", "variants": ["サーバ"] }
///       ]
///     }
///   }
/// }
/// ```
///
/// The object can also list the files to leave out under `exclude`, as
/// patterns relative to the directory of the configuration file (see
/// ``PathPattern`` for the syntax):
///
/// ```json
/// {
///   "exclude": ["vendor/**", "CHANGELOG.md"]
/// }
/// ```
///
/// Identifiers and option names that are not recognized are reported to the
/// handlers given to the initializer and otherwise ignored. A value of the
/// wrong type or out of range, and terms that contradict each other, make
/// loading fail with ``Error/invalidConfiguration(_:)``.
public struct RuleConfigurationLoader {
  public enum Error: Swift.Error, Equatable {
    case fileNotFound(String)
    /// The file is valid JSON but not a valid configuration. The associated
    /// value says what is wrong with it.
    case invalidConfiguration(String)
  }

  /// The name of the configuration file that
  /// ``findConfigurationFile(from:)`` looks for.
  public static let defaultFileName = ".mdlint.json"

  /// A closure invoked with the identifiers that could not be resolved.
  public typealias UnknownIdentifierHandler = ([String]) -> Void

  /// A closure invoked with the option names that a rule does not accept.
  public typealias UnknownOptionHandler = (_ ruleIdentifier: String, _ optionNames: [String]) ->
    Void

  private let fileManager: FileManager
  private let unknownIdentifierHandler: UnknownIdentifierHandler
  private let unknownOptionHandler: UnknownOptionHandler

  /// Creates a loader that reads configuration files using the specified
  /// file manager.
  ///
  /// - Parameters:
  ///   - fileManager: The file manager used to resolve configuration paths.
  ///   - unknownIdentifierHandler: A closure that receives any identifiers
  ///     that are not recognized.
  ///   - unknownOptionHandler: A closure that receives, for one rule at a
  ///     time, the option names that the rule does not accept.
  public init(
    fileManager: FileManager = .default,
    unknownIdentifierHandler: @escaping UnknownIdentifierHandler = { _ in },
    unknownOptionHandler: @escaping UnknownOptionHandler = { _, _ in }
  ) {
    self.fileManager = fileManager
    self.unknownIdentifierHandler = unknownIdentifierHandler
    self.unknownOptionHandler = unknownOptionHandler
  }

  /// Returns the path of the nearest configuration file.
  ///
  /// The search looks for a file named ``defaultFileName`` in the directory,
  /// then in each of its parent directories up to the root of the file
  /// system, and stops at the first one it finds.
  ///
  /// - Parameter directoryURL: The directory to start from.
  /// - Returns: The path of the file, or `nil` when there is none.
  public func findConfigurationFile(from directoryURL: URL) -> String? {
    let components = directoryURL.standardizedFileURL.path.split(separator: "/")

    for depth in (0...components.count).reversed() {
      let directory = "/" + components.prefix(depth).joined(separator: "/")
      let candidate = URL(fileURLWithPath: directory, isDirectory: true)
        .appendingPathComponent(Self.defaultFileName).path
      var isDirectory: ObjCBool = false
      if fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory),
        !isDirectory.boolValue
      {
        return candidate
      }
    }
    return nil
  }

  /// Returns the rules and the excluded files described by the
  /// configuration file.
  ///
  /// When `configurationPath` is `nil`, all default rules are returned and
  /// no file is excluded. Unknown identifiers and option names in the
  /// configuration are reported but ignored.
  ///
  /// - Parameters:
  ///   - configurationPath: The path to a JSON configuration file.
  ///   - politenessStyle: The style for the politeness-style consistency
  ///     rule. A value other than `nil` takes precedence over the `style`
  ///     option in the configuration file.
  /// - Throws: ``Error/fileNotFound(_:)`` when the configuration file does
  ///   not exist, ``Error/invalidConfiguration(_:)`` when its contents are
  ///   not a valid configuration, or a `DecodingError` when it is not JSON.
  /// - Returns: The resolved configuration.
  public func loadConfiguration(
    configurationPath: String?,
    politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle? = nil
  ) throws -> LintConfiguration {
    var options = DefaultRules.Options()
    if let politenessStyle { options.politenessStyle = politenessStyle }

    guard let configurationPath else {
      return LintConfiguration(rules: DefaultRules.all(options: options))
    }

    let configurationURL = URL(fileURLWithPath: configurationPath)
    guard fileManager.fileExists(atPath: configurationURL.path) else {
      throw Error.fileNotFound(configurationPath)
    }
    let directoryURL = configurationURL.deletingLastPathComponent()

    let data = try Data(contentsOf: configurationURL)
    switch try JSONDecoder().decode(JSONValue.self, from: data) {
    case .array(let names):
      return LintConfiguration(
        rules: DefaultRules.rules(for: try identifiers(listedIn: names), options: options),
        directoryURL: directoryURL)
    case .object(let configuration):
      if let unknownKey = configuration.keys.sorted().first(where: {
        $0 != "rules" && $0 != "exclude"
      }) {
        throw Error.invalidConfiguration(
          "unknown key \"\(unknownKey)\"; the supported keys are \"rules\" and \"exclude\"")
      }
      let settings = try settings(from: configuration)
      return LintConfiguration(
        rules: rules(for: settings, politenessStyle: politenessStyle),
        excludePatterns: try excludePatterns(from: configuration),
        directoryURL: directoryURL)
    default:
      throw Error.invalidConfiguration(
        "expected an array of rule identifiers or an object with a \"rules\" key")
    }
  }

  /// Returns the set of lint rules described by the configuration file.
  ///
  /// This is ``loadConfiguration(configurationPath:politenessStyle:)``
  /// without the excluded files.
  public func loadRules(
    configurationPath: String?,
    politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle? = nil
  ) throws -> [Rule] {
    try loadConfiguration(configurationPath: configurationPath, politenessStyle: politenessStyle)
      .rules
  }
}

// MARK: - Array form

extension RuleConfigurationLoader {
  private func identifiers(listedIn names: [JSONValue]) throws -> [DefaultRules.Identifier] {
    var identifiers: [DefaultRules.Identifier] = []
    var unknownIdentifiers: [String] = []

    for name in names {
      guard case .string(let name) = name else {
        throw Error.invalidConfiguration("the rule identifiers in the array must be strings")
      }
      if let identifier = DefaultRules.Identifier(name: name) {
        identifiers.append(identifier)
      } else {
        unknownIdentifiers.append(name)
      }
    }

    if !unknownIdentifiers.isEmpty {
      unknownIdentifierHandler(unknownIdentifiers)
    }
    return identifiers
  }
}

// MARK: - Object form

extension RuleConfigurationLoader {
  /// What the configuration file says about one rule.
  private struct Setting {
    var isEnabled = true
    var severity: Diagnostic.Severity?
    var max: Int?
    var style: JapanesePolitenessStyleConsistencyRule.PreferredStyle?
    var terms: [RegisteredTermRule.Term]?
  }

  private func settings(from configuration: [String: JSONValue]) throws
    -> [DefaultRules.Identifier: Setting]
  {
    guard let rules = configuration["rules"] else { return [:] }
    guard case .object(let entries) = rules else {
      throw Error.invalidConfiguration("\"rules\" must be an object keyed by rule identifier")
    }

    var settings: [DefaultRules.Identifier: Setting] = [:]
    var names: [DefaultRules.Identifier: String] = [:]
    var unknownIdentifiers: [String] = []

    // Sorted so that warnings and errors do not depend on the order of the
    // dictionary.
    for (name, value) in entries.sorted(by: { $0.key < $1.key }) {
      guard let identifier = DefaultRules.Identifier(name: name) else {
        unknownIdentifiers.append(name)
        continue
      }
      if let otherName = names[identifier] {
        throw Error.invalidConfiguration(
          "\"\(otherName)\" and \"\(name)\" name the same rule; keep only one of them")
      }
      names[identifier] = name
      settings[identifier] = try setting(for: identifier, named: name, from: value)
    }

    if !unknownIdentifiers.isEmpty {
      unknownIdentifierHandler(unknownIdentifiers)
    }
    return settings
  }

  private func setting(
    for identifier: DefaultRules.Identifier, named name: String, from value: JSONValue
  ) throws -> Setting {
    var setting = Setting()

    switch value {
    case .bool(let isEnabled):
      setting.isEnabled = isEnabled
      return setting
    case .object(let options):
      var unknownOptions: [String] = []
      for (option, value) in options.sorted(by: { $0.key < $1.key }) {
        switch (option, identifier) {
        case ("severity", _):
          guard case .string(let raw) = value, let severity = Diagnostic.Severity(rawValue: raw)
          else {
            throw Error.invalidConfiguration(
              "\"severity\" of \"\(name)\" must be \"info\", \"warning\", or \"error\"")
          }
          setting.severity = severity
        case ("max", .japaneseCommaLimit), ("max", .sentenceLengthLimit):
          guard case .integer(let max) = value, max >= 1 else {
            throw Error.invalidConfiguration(
              "\"max\" of \"\(name)\" must be an integer of 1 or more")
          }
          setting.max = max
        case ("style", .japanesePolitenessStyleConsistency):
          guard case .string(let raw) = value,
            let style = JapanesePolitenessStyleConsistencyRule.PreferredStyle(rawValue: raw)
          else {
            throw Error.invalidConfiguration(
              "\"style\" of \"\(name)\" must be \"auto\", \"desumasu\", or \"dearu\"")
          }
          setting.style = style
        case ("terms", .registeredTerm):
          setting.terms = try terms(from: value, ofRuleNamed: name)
        default:
          unknownOptions.append(option)
        }
      }
      if !unknownOptions.isEmpty {
        unknownOptionHandler(name, unknownOptions)
      }
      return setting
    default:
      throw Error.invalidConfiguration(
        "\"\(name)\" must be true, false, or an object of options")
    }
  }

  /// Reads the terms of the registered-term rule.
  ///
  /// Each term is an object with the keys `expected`, a string, and
  /// `variants`, an array of strings that may be empty.
  private func terms(from value: JSONValue, ofRuleNamed name: String) throws
    -> [RegisteredTermRule.Term]
  {
    guard case .array(let entries) = value else {
      throw Error.invalidConfiguration(
        "\"terms\" of \"\(name)\" must be an array of objects with \"expected\" and \"variants\"")
    }

    var terms: [RegisteredTermRule.Term] = []
    for (index, entry) in entries.enumerated() {
      guard case .object(let fields) = entry,
        case .string(let expected)? = fields["expected"],
        case .array(let values)? = fields["variants"]
      else {
        throw Error.invalidConfiguration(
          "\"terms[\(index)]\" of \"\(name)\" must be an object with a string \"expected\" "
            + "and an array of strings \"variants\"")
      }
      // A misspelled key would otherwise turn into a term that does less
      // than it says.
      if let unknownKey = fields.keys.sorted().first(where: {
        $0 != "expected" && $0 != "variants"
      }) {
        throw Error.invalidConfiguration(
          "\"terms[\(index)]\" of \"\(name)\" has the unknown key \"\(unknownKey)\"; "
            + "the supported keys are \"expected\" and \"variants\"")
      }
      let variants = try values.map { value -> String in
        guard case .string(let variant) = value else {
          throw Error.invalidConfiguration(
            "\"variants\" of \"terms[\(index)]\" of \"\(name)\" must be an array of strings")
        }
        return variant
      }
      terms.append(RegisteredTermRule.Term(expected: expected, variants: variants))
    }

    do {
      try RegisteredTermRule.validate(terms)
    } catch RegisteredTermRule.TermError.unusableSpelling(let spelling, let index) {
      throw Error.invalidConfiguration(
        spelling.isEmpty
          ? "\"terms[\(index)]\" of \"\(name)\" has an empty spelling"
          : "\"terms[\(index)]\" of \"\(name)\" has a spelling with a line break or a "
            + "reserved character")
    } catch RegisteredTermRule.TermError.expectedAndVariant(let spelling) {
      throw Error.invalidConfiguration(
        "\"terms\" of \"\(name)\" lists \"\(spelling)\" as both an expected spelling and a variant")
    } catch RegisteredTermRule.TermError.variantOfSeveralTerms(let spelling, let expected) {
      let list = expected.map { "\"\($0)\"" }.joined(separator: " and ")
      throw Error.invalidConfiguration(
        "\"terms\" of \"\(name)\" lists \"\(spelling)\" as a variant of \(list)")
    }
    return terms
  }

  /// Builds the default rule set with the settings applied.
  private func rules(
    for settings: [DefaultRules.Identifier: Setting],
    politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle?
  ) -> [Rule] {
    var options = DefaultRules.Options()
    if let max = settings[.japaneseCommaLimit]?.max { options.maxCommaCount = max }
    if let max = settings[.sentenceLengthLimit]?.max { options.maxSentenceLength = max }
    if let style = politenessStyle ?? settings[.japanesePolitenessStyleConsistency]?.style {
      options.politenessStyle = style
    }
    if let terms = settings[.registeredTerm]?.terms { options.terms = terms }

    return DefaultRules.Identifier.allCases.compactMap { identifier -> Rule? in
      let setting = settings[identifier] ?? Setting()
      guard setting.isEnabled else { return nil }
      let rule = identifier.makeRule(options: options)
      guard let severity = setting.severity else { return rule }
      return Self.overridingSeverity(of: rule, with: severity)
    }
  }

  private static func overridingSeverity<Base: Rule>(
    of rule: Base, with severity: Diagnostic.Severity
  ) -> any Rule {
    SeverityOverride(base: rule, severity: severity)
  }
}

// MARK: - Excluded files

extension RuleConfigurationLoader {
  private func excludePatterns(from configuration: [String: JSONValue]) throws -> [PathPattern] {
    guard let exclude = configuration["exclude"] else { return [] }
    guard case .array(let values) = exclude else {
      throw Error.invalidConfiguration("\"exclude\" must be an array of path patterns")
    }

    return try values.map { value in
      guard case .string(let string) = value else {
        throw Error.invalidConfiguration("\"exclude\" must be an array of path patterns")
      }
      guard let pattern = PathPattern(string) else {
        throw Error.invalidConfiguration(
          "the \"exclude\" pattern \"\(string)\" must be a path relative to the configuration file"
            + " that is not empty and has no \"..\"")
      }
      return pattern
    }
  }
}

// MARK: - Severity

/// Reports the diagnostics of another rule with a severity of its own.
///
/// The wrapper keeps the identifier of the rule it wraps and passes on the
/// fix-its of its diagnostics.
struct SeverityOverride<Base: Rule>: Rule {
  let base: Base
  let severity: Diagnostic.Severity

  var id: String { base.id }
  var description: String { base.description }

  func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    base.check(document: document, fileURL: fileURL, originalText: originalText).map {
      Diagnostic(
        file: $0.file, line: $0.line, column: $0.column, ruleID: $0.ruleID, message: $0.message,
        severity: severity, fixIt: $0.fixIt)
    }
  }
}

// MARK: - JSON

/// A JSON value of any type.
private enum JSONValue: Decodable {
  case null
  case bool(Bool)
  case integer(Int)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .integer(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSONValue].self))
    }
  }
}
