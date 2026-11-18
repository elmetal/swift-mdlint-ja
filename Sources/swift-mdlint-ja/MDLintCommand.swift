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
    let urls = resolveTargets(paths: paths)

    var allDiagnostics: [Diagnostic] = []

    for url in urls {
      guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        Self.warn("Skipping \(url.path): the file could not be read as UTF-8")
        continue
      }
      let (diagnostics, fixed) = linter.lint(content: content, fileURL: url, applyFixes: fix)
      allDiagnostics.append(contentsOf: diagnostics)

      if let fixed, fixed != content {
        do {
          try fixed.write(to: url, atomically: true, encoding: .utf8)
        } catch {
          Self.warn("Could not write fixes to \(url.path): \(error.localizedDescription)")
        }
      }
    }

    if allDiagnostics.isEmpty {
      print("✨ No rule violations found.")
    } else {
      for diagnostic in allDiagnostics.sorted(by: Diagnostic.sorter) {
        switch format {
        case .text: print(TextDiagnosticFormatStyle().format(diagnostic))
        case .gha: print(GHADiagnosticFormatStyle().format(diagnostic))
        }
      }
    }

    if strict && !allDiagnostics.isEmpty {
      throw ExitCode(2)
    }
  }

  private func resolveTargets(paths: [String]) -> [URL] {
    let fm = FileManager.default
    var urls: [URL] = []
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
        Self.warn("Skipping \(path): no such file or directory")
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
    return urls
  }

  private static func warn(_ message: String) {
    FileHandle.standardError.write(Data("warning: \(message)\n".utf8))
  }
}

extension JapanesePolitenessStyleConsistencyRule.PreferredStyle: ExpressibleByArgument {}
