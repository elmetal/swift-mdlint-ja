import Foundation
import ArgumentParser
import MDLintCore
import MDLintRules

@main
struct MDLintCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "mdlint-ja",
        abstract: "Minimal Japanese Markdown linter in Swift."
    )

    @Flag(name: [.short, .long], help: "Attempt to fix fixable violations in-place.")
    var fix: Bool = false

    @Option(name: [.customLong("format")], help: "Output format: text | gha (GitHub Actions).")
    var format: String = "text"

    @Flag(name: [.long], help: "Exit with non-zero status code when violations are found.")
    var strict: Bool = false

    @Option(name: [.customLong("config")], help: "Path to a JSON file listing rule identifiers to enable.")
    var configurationPath: String?

    @Argument(help: "Markdown files or directories to lint.")
    var paths: [String] = []

    mutating func run() throws {
        let fm = FileManager.default
        let linter = Linter(rules: try loadConfiguredRules(fileManager: fm))
        let urls = resolveTargets(paths: paths)

        var allDiagnostics: [Diagnostic] = []

        for url in urls {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let (diagnostics, fixed) = linter.lint(content: content, fileURL: url, applyFixes: fix)
            allDiagnostics.append(contentsOf: diagnostics)

            if fix, let fixed = fixed, fixed != content {
                try? fixed.write(to: url, atomically: true, encoding: .utf8)
            }
        }

        let format = ((format.lowercased() == "gha") ? GHADiagnosticFormatStyle().format : TextDiagnosticFormatStyle().format)

        allDiagnostics.sorted(by: Diagnostic.sorter).forEach { print(format($0)) }

        if strict && !allDiagnostics.isEmpty {
            throw ExitCode(2)
        }
    }

    private func loadConfiguredRules(fileManager: FileManager) throws -> [Rule] {
        guard let configurationPath else {
            return DefaultRules.all
        }

        let configurationURL = URL(fileURLWithPath: configurationPath)
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            throw ValidationError("Configuration file not found at \(configurationPath)")
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
            let warning = "warning: Ignoring unknown rule identifiers: \(unknownIdentifiers.joined(separator: ", "))\n"
            FileHandle.standardError.write(Data(warning.utf8))
        }

        return DefaultRules.rules(for: identifiers)
    }

    private func resolveTargets(paths: [String]) -> [URL] {
        let fm = FileManager.default
        var urls: [URL] = []

        let inputs: [URL]
        if paths.isEmpty {
            inputs = [URL(fileURLWithPath: ".")]
        } else {
            inputs = paths.map { URL(fileURLWithPath: $0) }
        }

        for input in inputs {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: input.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    let enumerator = fm.enumerator(at: input, includingPropertiesForKeys: nil)
                    while let file = enumerator?.nextObject() as? URL {
                        if file.pathExtension.lowercased() == "md" {
                            urls.append(file)
                        }
                    }
                } else if input.pathExtension.lowercased() == "md" {
                    urls.append(input)
                }
            }
        }
        return urls
    }
}
