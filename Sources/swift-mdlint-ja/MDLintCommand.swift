import ArgumentParser
import Foundation
import MDLintConfig
import MDLintCore
import MDLintRules

@main
struct MDLintCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mdlint-ja",
    abstract: "Minimal Japanese Markdown linter in Swift."
  )

  enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case text
    case gha

    /// Accepts the value case-insensitively (`--format GHA`).
    init?(argument: String) {
      self.init(rawValue: argument.lowercased())
    }
  }

  @Flag(name: [.short, .long], help: "Attempt to fix fixable violations in-place.")
  var fix: Bool = false

  @Option(name: [.customLong("format")], help: "Output format: text | gha (GitHub Actions).")
  var format: OutputFormat = .text

  @Flag(name: [.long], help: "Exit with non-zero status code when violations are found.")
  var strict: Bool = false

  @Option(
    name: [.customLong("config")], help: "Path to a JSON file listing rule identifiers to enable.")
  var configurationPath: String?

  @Option(
    name: [.customLong("politeness-style")],
    help: "Preferred Japanese politeness style: auto | desumasu | dearu.")
  var politenessStyle: JapanesePolitenessStyleConsistencyRule.PreferredStyle = .auto

  @Argument(help: "Markdown files or directories to lint.")
  var paths: [String] = []

  mutating func run() throws {
    let loader = RuleConfigurationLoader(
      unknownIdentifierHandler: { unknownIdentifiers in
        Self.warn(
          "Ignoring unknown rule identifiers: \(unknownIdentifiers.joined(separator: ", "))")
      })

    let rules: [Rule]
    do {
      rules = try loader.loadRules(
        configurationPath: configurationPath,
        options: .init(politenessStyle: politenessStyle))
    } catch RuleConfigurationLoader.Error.fileNotFound(let path) {
      throw ValidationError("Configuration file not found at \(path)")
    } catch is DecodingError {
      throw ValidationError(
        "Configuration file at \(configurationPath ?? "") must be a JSON array of rule identifier strings"
      )
    }

    let linter = Linter(rules: rules)
    let (urls, missingPaths) = resolveTargets(paths: paths)

    var allDiagnostics: [Diagnostic] = []

    for url in urls {
      guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        Self.warn("Skipping \(url.path): the file could not be read as UTF-8")
        continue
      }
      var (diagnostics, fixed) = linter.lint(content: content, fileURL: url, applyFixes: fix)

      if let fixed, fixed != content {
        do {
          try fixed.write(to: url, atomically: true, encoding: .utf8)
          // Report what is left in the rewritten file so that locations match
          // the file on disk and `--strict` only fails for remaining violations.
          diagnostics = linter.lint(content: fixed, fileURL: url, applyFixes: false).0
        } catch {
          Self.warn("Could not write fixes to \(url.path): \(error.localizedDescription)")
        }
      }
      allDiagnostics.append(contentsOf: diagnostics)
    }

    if allDiagnostics.isEmpty {
      // Not everything that was asked for was linted when a path is missing,
      // so the run cannot claim that there are no violations.
      if missingPaths.isEmpty {
        print("✨ No rule violations found.")
      }
    } else {
      for diagnostic in allDiagnostics.sorted(by: Diagnostic.sorter) {
        switch format {
        case .text: print(TextDiagnosticFormatStyle().format(diagnostic))
        case .gha: print(GHADiagnosticFormatStyle().format(diagnostic))
        }
      }
    }

    // A path that does not exist is most likely a typo. The remaining paths
    // are still linted and reported above, but the run fails so that a
    // mistyped path in a CI job does not pass silently.
    if !missingPaths.isEmpty {
      throw ExitCode.failure
    }

    if strict && !allDiagnostics.isEmpty {
      throw ExitCode(2)
    }
  }

  /// Collects the Markdown files to lint.
  ///
  /// - Returns: The files, and the arguments that name neither a file nor a
  ///   directory.
  private func resolveTargets(paths: [String]) -> (urls: [URL], missingPaths: [String]) {
    let fm = FileManager.default
    var urls: [URL] = []
    var missingPaths: [String] = []
    var seenPaths: Set<String> = []

    func add(_ url: URL) {
      // The same file can be reached through several arguments (`. README.md`).
      if seenPaths.insert(url.standardizedFileURL.path).inserted {
        urls.append(url)
      }
    }

    let inputs = paths.isEmpty ? ["."] : paths

    for path in inputs {
      let input = URL(fileURLWithPath: path)
      var isDir: ObjCBool = false
      guard fm.fileExists(atPath: input.path, isDirectory: &isDir) else {
        Self.reportError("\(path): no such file or directory")
        missingPaths.append(path)
        continue
      }

      if isDir.boolValue {
        // Hidden entries are skipped so that `.build`, `.git`, and similar
        // directories are neither linted nor rewritten by `--fix`.
        let enumerator = fm.enumerator(
          at: input, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        while let file = enumerator?.nextObject() as? URL {
          if file.pathExtension.lowercased() == "md" {
            add(file)
          }
        }
      } else if input.pathExtension.lowercased() == "md" {
        add(input)
      }
    }
    return (urls, missingPaths)
  }

  private static func warn(_ message: String) {
    FileHandle.standardError.write(Data("warning: \(message)\n".utf8))
  }

  private static func reportError(_ message: String) {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
  }
}

extension JapanesePolitenessStyleConsistencyRule.PreferredStyle: ExpressibleByArgument {}
