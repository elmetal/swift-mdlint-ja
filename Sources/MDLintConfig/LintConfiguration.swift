import Foundation
import MDLintCore

/// What a configuration file says about a run: the rules to apply and the
/// files to leave out.
public struct LintConfiguration {
  /// The rules to run.
  public let rules: [Rule]

  /// The patterns of the files that are not linted.
  ///
  /// The patterns are relative to ``directoryURL``.
  public let excludePatterns: [PathPattern]

  /// The directory that holds the configuration file, or `nil` when there is
  /// no configuration file.
  public let directoryURL: URL?

  private let directoryComponents: [String]

  /// Creates a configuration.
  ///
  /// - Parameters:
  ///   - rules: The rules to run.
  ///   - excludePatterns: The patterns of the files that are not linted.
  ///   - directoryURL: The directory that the patterns are relative to.
  public init(rules: [Rule], excludePatterns: [PathPattern] = [], directoryURL: URL? = nil) {
    self.rules = rules
    self.excludePatterns = excludePatterns
    self.directoryURL = directoryURL
    self.directoryComponents = directoryURL.map(Self.pathComponents(of:)) ?? []
  }

  /// Returns whether the file or directory is left out of the run.
  ///
  /// The path is compared as it is written, without resolving symbolic
  /// links. A path outside ``directoryURL`` is never excluded.
  public func excludes(_ fileURL: URL) -> Bool {
    guard directoryURL != nil, !excludePatterns.isEmpty else { return false }

    let fileComponents = Self.pathComponents(of: fileURL)
    guard fileComponents.count > directoryComponents.count,
      fileComponents.starts(with: directoryComponents)
    else { return false }

    let relativeComponents = fileComponents.dropFirst(directoryComponents.count)
    return excludePatterns.contains { $0.matches(pathComponents: relativeComponents) }
  }

  private static func pathComponents(of url: URL) -> [String] {
    url.standardizedFileURL.path.split(separator: "/").map(String.init)
  }
}
