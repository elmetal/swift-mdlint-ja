import Foundation
import ArgumentParser
import MDLintCore
import MDLintRules
import MDLintConfig

@main
struct MDLintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
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
        let loader = RuleConfigurationLoader(fileManager: fm, unknownIdentifierHandler: { unknownIdentifiers in
            let warning = "warning: Ignoring unknown rule identifiers: \(unknownIdentifiers.joined(separator: ", "))\n"
            FileHandle.standardError.write(Data(warning.utf8))
        })

        let rules: [Rule]
        do {
            rules = try loader.loadRules(configurationPath: configurationPath)
        } catch RuleConfigurationLoader.Error.fileNotFound(let path) {
            throw ValidationError("Configuration file not found at \(path)")
        }

        let linter = Linter(rules: rules)
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

        if allDiagnostics.isEmpty {
            print("✨ No rule violations found.")
        } else {
            allDiagnostics.sorted(by: Diagnostic.sorter).forEach { print(format($0)) }
        }

        if strict && !allDiagnostics.isEmpty {
            throw ExitCode(2)
        }
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
