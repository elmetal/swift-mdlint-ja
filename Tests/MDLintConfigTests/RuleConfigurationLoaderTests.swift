import Foundation
import MDLintRules
@testable import MDLintConfig
import Testing

@Suite("RuleConfigurationLoader")
struct RuleConfigurationLoaderTests {
    @Test("returns all rules when configuration path is nil")
    func returnsAllRulesWhenConfigurationPathIsNil() throws {
        let loader = RuleConfigurationLoader()
        let rules = try loader.loadRules(configurationPath: nil)

        #expect(rules.map(\.id).sorted() == DefaultRules.all.map(\.id).sorted())
    }

    @Test("loads rules from configuration file")
    func loadsRulesFromConfigurationFile() throws {
        let temporaryURL = try makeTemporaryConfigurationFile(contents: [
            "ja.ellipsis.prefer-double",
            "ja.period.prefer-fullwidth"
        ])
        let loader = RuleConfigurationLoader()

        let rules = try loader.loadRules(configurationPath: temporaryURL.path)

        #expect(rules.map(\.id) == [
            "ja.ellipsis.prefer-double",
            "ja.period.prefer-fullwidth"
        ])
    }

    @Test("warns about unknown identifiers")
    func warnsAboutUnknownIdentifiers() throws {
        let temporaryURL = try makeTemporaryConfigurationFile(contents: [
            "ja.ellipsis.prefer-double",
            "unknown.rule"
        ])
        var warnedIdentifiers: [String] = []
        let loader = RuleConfigurationLoader { identifiers in
            warnedIdentifiers = identifiers
        }

        _ = try loader.loadRules(configurationPath: temporaryURL.path)

        #expect(warnedIdentifiers == ["unknown.rule"])
    }

    @Test("throws when configuration file is missing")
    func throwsWhenConfigurationFileIsMissing() {
        let loader = RuleConfigurationLoader(fileManager: .default)

        #expect(throws: RuleConfigurationLoader.Error.fileNotFound("/path/to/missing.json")) {
            try loader.loadRules(configurationPath: "/path/to/missing.json")
        }
    }

    private func makeTemporaryConfigurationFile(contents: [String]) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("config.json")
        let data = try JSONEncoder().encode(contents)
        try data.write(to: fileURL)
        return fileURL
    }
}
