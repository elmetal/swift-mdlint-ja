import XCTest
@testable import MDLintConfig
import MDLintRules

final class RuleConfigurationLoaderTests: XCTestCase {
    func testReturnsAllRulesWhenConfigurationPathIsNil() throws {
        let loader = RuleConfigurationLoader()
        let rules = try loader.loadRules(configurationPath: nil)

        XCTAssertEqual(rules.map(\.id).sorted(), DefaultRules.all.map(\.id).sorted())
    }

    func testLoadsRulesFromConfigurationFile() throws {
        let temporaryURL = try makeTemporaryConfigurationFile(contents: [
            "ja.ellipsis.prefer-double",
            "ja.period.prefer-fullwidth"
        ])
        let loader = RuleConfigurationLoader()

        let rules = try loader.loadRules(configurationPath: temporaryURL.path)

        XCTAssertEqual(rules.map(\.id), [
            "ja.ellipsis.prefer-double",
            "ja.period.prefer-fullwidth"
        ])
    }

    func testWarnsAboutUnknownIdentifiers() throws {
        let temporaryURL = try makeTemporaryConfigurationFile(contents: [
            "ja.ellipsis.prefer-double",
            "unknown.rule"
        ])
        var warnedIdentifiers: [String] = []
        let loader = RuleConfigurationLoader { identifiers in
            warnedIdentifiers = identifiers
        }

        _ = try loader.loadRules(configurationPath: temporaryURL.path)

        XCTAssertEqual(warnedIdentifiers, ["unknown.rule"])
    }

    func testThrowsWhenConfigurationFileIsMissing() throws {
        let loader = RuleConfigurationLoader(fileManager: .default)

        XCTAssertThrowsError(try loader.loadRules(configurationPath: "/path/to/missing.json")) { error in
            XCTAssertEqual(error as? RuleConfigurationLoader.Error, .fileNotFound("/path/to/missing.json"))
        }
    }

    // MARK: - Helpers

    private func makeTemporaryConfigurationFile(contents: [String]) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("config.json")
        let data = try JSONEncoder().encode(contents)
        try data.write(to: fileURL)
        return fileURL
    }
}
