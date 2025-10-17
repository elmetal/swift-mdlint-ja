import Foundation
import MDLintCore
import MDLintRules

public struct RuleConfigurationLoader {
    public enum Error: Swift.Error, Equatable {
        case fileNotFound(String)
    }

    public typealias WarningHandler = ([String]) -> Void

    private let fileManager: FileManager
    private let warningHandler: WarningHandler

    public init(fileManager: FileManager = .default, warningHandler: @escaping WarningHandler = { _ in }) {
        self.fileManager = fileManager
        self.warningHandler = warningHandler
    }

    public func loadRules(configurationPath: String?) throws -> [Rule] {
        guard let configurationPath else {
            return DefaultRules.all
        }

        let configurationURL = URL(fileURLWithPath: configurationPath)
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            throw Error.fileNotFound(configurationPath)
        }

        let data = try Data(contentsOf: configurationURL)
        let rawIdentifiers = try JSONDecoder().decode([String].self, from: data)

        var identifiers: [DefaultRules.Identifier] = []
        var unknownIdentifiers: [String] = []

        for raw in rawIdentifiers {
            if let identifier = DefaultRules.Identifier(rawValue: raw) {
                identifiers.append(identifier)
            } else {
                unknownIdentifiers.append(raw)
            }
        }

        if !unknownIdentifiers.isEmpty {
            warningHandler(unknownIdentifiers)
        }

        return DefaultRules.rules(for: identifiers)
    }
}
