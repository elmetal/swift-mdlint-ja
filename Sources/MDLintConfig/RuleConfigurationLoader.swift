import Foundation
import MDLintCore
import MDLintRules

/// Loads lint rule identifiers from an `.mdlintconfig` JSON file.
///
/// ``RuleConfigurationLoader`` decodes the configuration file into
/// ``DefaultRules.Identifier`` values and resolves them into concrete rules.
/// Unknown identifiers are reported to ``UnknownIdentifierHandler`` so callers
/// can surface a warning before proceeding with the known rules only.
public struct RuleConfigurationLoader {
    public enum Error: Swift.Error, Equatable {
        case fileNotFound(String)
    }

    /// A closure invoked with the identifiers that could not be resolved.
    public typealias UnknownIdentifierHandler = ([String]) -> Void

    private let fileManager: FileManager
    private let unknownIdentifierHandler: UnknownIdentifierHandler

    /// Creates a loader that reads configuration files using the specified
    /// file manager.
    ///
    /// - Parameters:
    ///   - fileManager: The file manager used to resolve configuration paths.
    ///   - unknownIdentifierHandler: A closure that receives any identifiers
    ///     that are not recognized.
    public init(fileManager: FileManager = .default, unknownIdentifierHandler: @escaping UnknownIdentifierHandler = { _ in }) {
        self.fileManager = fileManager
        self.unknownIdentifierHandler = unknownIdentifierHandler
    }

    /// Returns the set of lint rules described by the configuration file.
    ///
    /// When `configurationPath` is `nil`, all default rules are returned.
    /// Unknown identifiers in the configuration are reported but ignored.
    ///
    /// - Parameter configurationPath: The path to a JSON file containing rule
    ///   identifiers.
    /// - Throws: ``Error/fileNotFound(_:)`` when the configuration file does
    ///   not exist, or an error if the JSON cannot be decoded.
    /// - Returns: The resolved lint rules.
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
            unknownIdentifierHandler(unknownIdentifiers)
        }

        return DefaultRules.rules(for: identifiers)
    }
}
