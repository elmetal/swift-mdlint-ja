import Foundation
import Testing

private final class BundleMarker {}

/// Directory that holds the built `mdlint-ja` executable.
private var productsDirectory: URL {
  #if os(macOS)
    return Bundle(for: BundleMarker.self).bundleURL.deletingLastPathComponent()
  #else
    return Bundle.main.bundleURL
  #endif
}

private struct CommandResult {
  var status: Int32
  var stdout: String
  var stderr: String
}

private func runMDLint(_ arguments: [String], in directory: URL) throws -> CommandResult {
  let process = Process()
  process.executableURL = productsDirectory.appendingPathComponent("mdlint-ja")
  process.arguments = arguments
  process.currentDirectoryURL = directory
  let out = Pipe()
  let err = Pipe()
  process.standardOutput = out
  process.standardError = err
  try process.run()
  let stdout = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  process.waitUntilExit()
  return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
}

private func makeTree(_ files: [String: String]) throws -> URL {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("mdlint-ja-tests-\(UUID().uuidString)")
  for (path, content) in files {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try content.write(to: url, atomically: true, encoding: .utf8)
  }
  return root
}

@Suite("mdlint-ja command")
struct MDLintCommandTests {
  @Test("lints a file once when several arguments reach it")
  func lintsFileOnceWhenReachableThroughSeveralArguments() throws {
    let root = try makeTree(["sub/s.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let once = try runMDLint(["sub/s.md"], in: root)
    let repeated = try runMDLint([".", "sub/s.md", "sub", "./sub/../sub/s.md"], in: root)

    let onceLines = once.stdout.split(separator: "\n")
    let repeatedLines = repeated.stdout.split(separator: "\n")
    #expect(!onceLines.isEmpty)
    #expect(!once.stdout.contains("No rule violations"))
    #expect(repeatedLines.count == onceLines.count)
  }

  @Test("fails for a path that does not exist but still lints the rest")
  func failsForMissingPath() throws {
    let root = try makeTree(["a.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let baseline = try runMDLint(["a.md"], in: root)
    let result = try runMDLint(["typo.md", "a.md"], in: root)

    #expect(baseline.stderr.isEmpty)
    #expect(baseline.status == 0)
    #expect(result.stderr == "error: typo.md: no such file or directory\n")
    #expect(result.stdout == baseline.stdout)
    #expect(result.status == 1)
  }

  @Test("reports every missing path and does not claim a clean run")
  func reportsEveryMissingPath() throws {
    let root = try makeTree(["clean.md": "これはテストです。\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let clean = try runMDLint(["clean.md"], in: root)
    let result = try runMDLint(["typo.md", "clean.md", "no-such-directory"], in: root)

    #expect(clean.status == 0)
    #expect(clean.stdout.contains("No rule violations"))
    #expect(
      result.stderr
        == "error: typo.md: no such file or directory\n"
        + "error: no-such-directory: no such file or directory\n")
    #expect(result.stdout.isEmpty)
    #expect(result.status == 1)
  }

  @Test("exits with 1 for a missing path even when --strict finds violations")
  func missingPathTakesPrecedenceOverStrict() throws {
    let root = try makeTree(["a.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let strict = try runMDLint(["--strict", "a.md"], in: root)
    let result = try runMDLint(["--strict", "typo.md", "a.md"], in: root)

    #expect(strict.status == 2)
    #expect(result.stdout == strict.stdout)
    #expect(result.status == 1)
  }

  @Test("still fixes the files that exist when another path is missing")
  func fixesExistingFilesDespiteMissingPath() throws {
    let root = try makeTree(["a.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--fix", "typo.md", "a.md"], in: root)

    let fixed = try String(contentsOf: root.appendingPathComponent("a.md"), encoding: .utf8)
    #expect(fixed == "これはテストです。\n")
    #expect(result.status == 1)
  }

  @Test("warns about a file that is not valid UTF-8 and lints the rest")
  func warnsAboutNonUTF8File() throws {
    let root = try makeTree(["a.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let baseline = try runMDLint(["."], in: root)

    // "あいう" in Shift_JIS, which is not a valid UTF-8 byte sequence.
    let shiftJIS = Data([0x82, 0xA0, 0x82, 0xA2, 0x82, 0xA4, 0x0A])
    try shiftJIS.write(to: root.appendingPathComponent("sjis.md"))

    let result = try runMDLint(["."], in: root)

    let warnings = result.stderr.split(separator: "\n")
    #expect(warnings.count == 1)
    #expect(result.stderr.hasPrefix("warning: Skipping "))
    #expect(result.stderr.hasSuffix("sjis.md: the file could not be read as UTF-8\n"))
    #expect(result.stdout == baseline.stdout)
    #expect(result.status == baseline.status)
  }

  @Test("rewrites a file only when --fix is given")
  func rewritesFileOnlyWithFix() throws {
    let original = "これはテストです.\n"
    let root = try makeTree(["a.md": original])
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("a.md")

    let dryRun = try runMDLint(["a.md"], in: root)
    #expect(dryRun.stderr.isEmpty)
    #expect(try String(contentsOf: file, encoding: .utf8) == original)

    let fixing = try runMDLint(["--fix", "a.md"], in: root)
    #expect(fixing.stderr.isEmpty)
    #expect(try String(contentsOf: file, encoding: .utf8) != original)
  }

  // The superuser can write into a read-only directory, so the failure cannot be provoked.
  @Test("warns when fixes cannot be written back", .enabled(if: getuid() != 0))
  func warnsWhenFixesCannotBeWritten() throws {
    let original = "これはテストです.\n"
    let root = try makeTree(["locked/a.md": original])
    let directory = root.appendingPathComponent("locked")
    let file = directory.appendingPathComponent("a.md")
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: directory.path)
      try? FileManager.default.removeItem(at: root)
    }

    let dryRun = try runMDLint(["locked/a.md"], in: root)

    // An atomic write replaces the file, which a read-only directory forbids.
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
    let result = try runMDLint(["--fix", "locked/a.md"], in: root)

    let warnings = result.stderr.split(separator: "\n")
    #expect(warnings.count == 1)
    #expect(result.stderr.hasPrefix("warning: Could not write fixes to "))
    #expect(result.stderr.contains("locked/a.md: "))
    #expect(result.stdout == dryRun.stdout)
    #expect(result.status == dryRun.status)
    #expect(try String(contentsOf: file, encoding: .utf8) == original)
  }

  @Test(
    "prints plain text diagnostics by default and for --format text",
    arguments: [[], ["--format", "text"], ["--format", "TEXT"]])
  func printsTextDiagnostics(formatArguments: [String]) throws {
    let root = try makeTree(["s.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(formatArguments + ["s.md"], in: root)

    let lines = result.stdout.split(separator: "\n")
    #expect(result.status == 0)
    #expect(!lines.isEmpty)
    #expect(lines.allSatisfy { !$0.hasPrefix("::") })
  }

  @Test(
    "prints workflow commands for --format gha, whatever the case",
    arguments: ["gha", "GHA", "Gha"])
  func printsWorkflowCommands(format: String) throws {
    let root = try makeTree(["s.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--format", format, "s.md"], in: root)

    let lines = result.stdout.split(separator: "\n")
    #expect(result.status == 0)
    #expect(!lines.isEmpty)
    #expect(lines.allSatisfy { $0.hasPrefix("::") })
  }

  @Test("rejects an unknown --format value with a usage error")
  func rejectsUnknownFormat() throws {
    let root = try makeTree(["s.md": "これはテストです.\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--format", "json", "s.md"], in: root)

    #expect(result.status == 64)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.contains("--format"))
    #expect(result.stderr.contains("json"))
  }

  // MARK: Configuration file

  @Test("runs only the rules listed in an array configuration")
  func runsOnlyRulesListedInArrayConfiguration() throws {
    let root = try makeTree([
      "s.md": "これは Test です.\n",
      "config.json": "[\"ja.period.prefer-fullwidth\", \"ja.comma.max-three\", \"no.such-rule\"]",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--config", "config.json", "s.md"], in: root)

    let lines = result.stdout.split(separator: "\n")
    #expect(result.status == 0)
    #expect(lines.count == 1)
    #expect(lines.first?.contains("[ja.period.prefer-fullwidth]") == true)
    #expect(result.stderr == "warning: Ignoring unknown rule identifiers: no.such-rule\n")
  }

  @Test("applies the options and severities of an object configuration")
  func appliesObjectConfiguration() throws {
    let config = """
      {
        "rules": {
          "ja.comma.max-count": { "max": 1, "severity": "error" },
          "ja.sentence.max-length": { "max": 5, "severity": "info" },
          "ja.spacing.no-space-between-japanese-and-english": false
        }
      }
      """
    let root = try makeTree(["s.md": "これは Test で、長く、続きます.\n", "config.json": config])
    defer { try? FileManager.default.removeItem(at: root) }

    let text = try runMDLint(["--config", "config.json", "s.md"], in: root)
    let gha = try runMDLint(["--config", "config.json", "--format", "gha", "s.md"], in: root)

    let textLines = text.stdout.split(separator: "\n").map(String.init)
    #expect(text.status == 0)
    #expect(text.stderr.isEmpty)
    #expect(textLines.count == 3)
    #expect(textLines.contains { $0.hasPrefix("[ERROR]") && $0.contains("[ja.comma.max-count]") })
    #expect(
      textLines.contains { $0.hasPrefix("[INFO]") && $0.contains("[ja.sentence.max-length]") })
    #expect(
      textLines.contains {
        $0.hasPrefix("[WARNING]") && $0.contains("[ja.period.prefer-fullwidth]")
      }
    )

    let ghaLines = gha.stdout.split(separator: "\n").map(String.init)
    #expect(ghaLines.count == 3)
    #expect(ghaLines.filter { $0.hasPrefix("::error ") }.count == 1)
    #expect(ghaLines.filter { $0.hasPrefix("::notice ") }.count == 1)
    #expect(ghaLines.filter { $0.hasPrefix("::warning ") }.count == 1)
  }

  @Test("warns about options that a rule does not accept")
  func warnsAboutUnknownOptions() throws {
    let root = try makeTree([
      "s.md": "これはテストです。\n",
      "config.json": "{\"rules\": {\"ja.kana.no-halfwidth\": {\"max\": 3, \"limit\": 1}}}",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--config", "config.json", "s.md"], in: root)

    #expect(result.status == 0)
    #expect(
      result.stderr == "warning: Ignoring unknown options of ja.kana.no-halfwidth: limit, max\n")
  }

  @Test(
    "lets --politeness-style override the configuration file",
    arguments: [
      ([String](), "です"), (["--politeness-style", "desumasu"], "である"),
      (["--politeness-style", "auto"], ""),
    ])
  func politenessStyleOptionOverridesConfiguration(arguments: [String], reported: String) throws {
    let root = try makeTree([
      "s.md": "これはテストです。\n\nこれはテストである。\n",
      "config.json": "{\"rules\": {\"ja.style.no-mix-dearu-desumasu\": {\"style\": \"dearu\"}}}",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(arguments + ["--config", "config.json", "s.md"], in: root)

    let lines = result.stdout.split(separator: "\n").filter { $0.contains("[ja.style.") }
    #expect(result.status == 0)
    if reported.isEmpty {
      // Neither style is in the majority, so `auto` reports nothing.
      #expect(lines.isEmpty)
    } else {
      #expect(lines.count == 1)
      #expect(lines.first?.contains(reported == "です" ? "s.md:1:" : "s.md:3:") == true)
    }
  }

  @Test(
    "rejects an invalid configuration file with a usage error",
    arguments: [
      ("{\"rules\": {\"ja.comma.max-count\": {\"max\": 0}}}", "must be an integer of 1 or more"),
      ("{\"rules\": {\"ja.kana.no-halfwidth\": {\"severity\": \"fatal\"}}}", "\"severity\""),
      ("{\"rule\": {}}", "unknown key \"rule\""),
      ("\"ja.kana.no-halfwidth\"", "expected an array of rule identifiers or an object"),
      ("{", "is not valid JSON"),
    ])
  func rejectsInvalidConfiguration(config: String, message: String) throws {
    let root = try makeTree(["s.md": "これはテストです.\n", "config.json": config])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--config", "config.json", "s.md"], in: root)

    #expect(result.status == 64)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.contains("config.json"))
    #expect(result.stderr.contains(message))
  }

  @Test("keeps the exit codes independent of severity")
  func exitCodesDoNotDependOnSeverity() throws {
    let root = try makeTree([
      "s.md": "これはテストです.\n",
      "error.json": "{\"rules\": {\"ja.period.prefer-fullwidth\": {\"severity\": \"error\"}}}",
      "info.json": "{\"rules\": {\"ja.period.prefer-fullwidth\": {\"severity\": \"info\"}}}",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(try runMDLint(["--config", "error.json", "s.md"], in: root).status == 0)
    #expect(try runMDLint(["--config", "info.json", "--strict", "s.md"], in: root).status == 2)
  }
}

/// A file with one violation, of `ja.period.prefer-fullwidth`.
private let violating = "これはテストです.\n"

/// Turns off the only rule that `violating` breaks.
private let periodRuleOff = "{\"rules\": {\"ja.period.prefer-fullwidth\": false}}"

/// The files that have diagnostics in the output, relative to `root`.
private func reportedFiles(_ result: CommandResult, under root: URL) -> [String] {
  let marker = root.lastPathComponent + "/"
  let files = result.stdout.split(separator: "\n").compactMap { line -> String? in
    guard let range = line.range(of: marker) else { return nil }
    return line[range.upperBound...].split(separator: ":").first.map(String.init)
  }
  return Set(files).sorted()
}

@Suite("mdlint-ja command: finding the configuration file")
struct MDLintCommandDiscoveryTests {
  @Test("uses .mdlint.json from the current directory")
  func usesFileInCurrentDirectory() throws {
    let root = try makeTree(["s.md": violating, ".mdlint.json": periodRuleOff])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["s.md"], in: root)

    #expect(result.status == 0)
    #expect(result.stderr.isEmpty)
    #expect(result.stdout.contains("No rule violations"))
  }

  @Test("uses .mdlint.json from a parent directory", arguments: [["s.md"], [], ["."], ["../.."]])
  func usesFileInParentDirectory(arguments: [String]) throws {
    let root = try makeTree(["docs/guide/s.md": violating, ".mdlint.json": periodRuleOff])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(arguments, in: root.appendingPathComponent("docs/guide"))

    #expect(result.status == 0)
    #expect(result.stderr.isEmpty)
    #expect(result.stdout.contains("No rule violations"))
  }

  @Test("uses the nearest .mdlint.json and does not merge it with the ones above")
  func usesNearestFile() throws {
    let root = try makeTree([
      "docs/s.md": "これは Test です.\n",
      ".mdlint.json": periodRuleOff,
      "docs/.mdlint.json":
        "{\"rules\": {\"ja.spacing.no-space-between-japanese-and-english\": false}}",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let nearest = try runMDLint(["s.md"], in: root.appendingPathComponent("docs"))
    let fromRoot = try runMDLint(["docs/s.md"], in: root)

    // The file is chosen by the current directory, not by the linted file.
    #expect(nearest.stdout.contains("[ja.period.prefer-fullwidth]"))
    #expect(!nearest.stdout.contains("[ja.spacing."))
    #expect(!fromRoot.stdout.contains("[ja.period.prefer-fullwidth]"))
    #expect(fromRoot.stdout.contains("[ja.spacing."))
  }

  @Test("runs every rule with its defaults when there is no configuration file")
  func runsDefaultsWithoutFile() throws {
    let root = try makeTree(["docs/s.md": violating, "mdlint.json": periodRuleOff])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--strict"], in: root.appendingPathComponent("docs"))
    let withoutDiscovery = try runMDLint(
      ["--strict", "--no-config"], in: root.appendingPathComponent("docs"))

    #expect(result.status == 2)
    #expect(result.stderr.isEmpty)
    #expect(result.stdout.contains("[ja.period.prefer-fullwidth]"))
    #expect(result.stdout == withoutDiscovery.stdout)
  }

  @Test("lets --config take precedence over .mdlint.json")
  func configOptionTakesPrecedence() throws {
    let root = try makeTree([
      "s.md": "これは Test です.\n",
      ".mdlint.json": periodRuleOff,
      "other.json": "[\"ja.period.prefer-fullwidth\"]",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let discovered = try runMDLint(["s.md"], in: root)
    let explicit = try runMDLint(["--config", "other.json", "s.md"], in: root)

    #expect(!discovered.stdout.contains("[ja.period.prefer-fullwidth]"))
    #expect(discovered.stdout.contains("[ja.spacing."))
    let lines = explicit.stdout.split(separator: "\n")
    #expect(lines.count == 1)
    #expect(lines.first?.contains("[ja.period.prefer-fullwidth]") == true)
  }

  @Test("does not fall back to .mdlint.json when the --config file is missing")
  func missingConfigOptionFileIsAnError() throws {
    let root = try makeTree(["s.md": violating, ".mdlint.json": periodRuleOff])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--config", "typo.json", "s.md"], in: root)

    #expect(result.status == 64)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.contains("Configuration file not found at typo.json"))
  }

  @Test("ignores .mdlint.json with --no-config")
  func noConfigIgnoresFile() throws {
    let root = try makeTree([
      "s.md": violating, "vendor/v.md": violating,
      ".mdlint.json":
        "{\"rules\": {\"ja.period.prefer-fullwidth\": false}, \"exclude\": [\"vendor\"]}",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--no-config"], in: root)

    #expect(result.status == 0)
    #expect(result.stderr.isEmpty)
    #expect(reportedFiles(result, under: root) == ["s.md", "vendor/v.md"])
  }

  @Test("does not read an invalid .mdlint.json with --no-config")
  func noConfigSkipsInvalidFile() throws {
    let root = try makeTree(["s.md": violating, ".mdlint.json": "{"])
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(try runMDLint(["s.md"], in: root).status == 64)
    #expect(try runMDLint(["--no-config", "s.md"], in: root).status == 0)
  }

  @Test("rejects --config together with --no-config")
  func rejectsConfigWithNoConfig() throws {
    let root = try makeTree(["s.md": violating, "config.json": periodRuleOff])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["--config", "config.json", "--no-config", "s.md"], in: root)

    #expect(result.status == 64)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.contains("--config and --no-config cannot be used together"))
  }

  @Test("names the discovered file when it is not valid")
  func namesInvalidDiscoveredFile() throws {
    let root = try makeTree(["docs/s.md": violating, ".mdlint.json": "{\"exclude\": \"vendor\"}"])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["s.md"], in: root.appendingPathComponent("docs"))

    #expect(result.status == 64)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.contains("\(root.lastPathComponent)/.mdlint.json is not valid"))
    #expect(result.stderr.contains("\"exclude\" must be an array of path patterns"))
  }

  @Test("still warns about unknown rules in a discovered file")
  func warnsAboutUnknownRulesInDiscoveredFile() throws {
    let root = try makeTree([
      "s.md": "これはテストです。\n", ".mdlint.json": "{\"rules\": {\"no.such-rule\": false}}",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["s.md"], in: root)

    #expect(result.status == 0)
    #expect(result.stderr == "warning: Ignoring unknown rule identifiers: no.such-rule\n")
  }
}

@Suite("mdlint-ja command: excluded files")
struct MDLintCommandExcludeTests {
  private static let tree: [String: String] = [
    ".mdlint.json": "{\"exclude\": [\"vendor/**\", \"CHANGELOG.md\", \"**/draft-*.md\"]}",
    "README.md": violating,
    "CHANGELOG.md": violating,
    "vendor/v.md": violating,
    "vendor/deep/w.md": violating,
    "docs/CHANGELOG.md": violating,
    "docs/a.md": violating,
    "docs/draft-1.md": violating,
    "docs/draft-2.md": violating,
    "docs/z.md": violating,
    "docs/vendor/kept.md": violating,
    "docs/sub/draft-3.md": violating,
    "docs/sub/s.md": violating,
  ]

  private static let kept = [
    "README.md", "docs/CHANGELOG.md", "docs/a.md", "docs/sub/s.md", "docs/vendor/kept.md",
    "docs/z.md",
  ]

  @Test("skips the files that match exclude while walking directories")
  func skipsExcludedFiles() throws {
    let root = try makeTree(Self.tree)
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint([], in: root)
    let everything = try runMDLint(["--no-config"], in: root)

    #expect(result.status == 0)
    #expect(result.stderr.isEmpty)
    #expect(reportedFiles(result, under: root) == Self.kept)
    #expect(
      reportedFiles(everything, under: root)
        == Self.tree.keys.filter { $0.hasSuffix(".md") }.sorted())
  }

  @Test("matches the patterns from the directory of the file, wherever the command runs")
  func matchesFromDirectoryOfConfigurationFile() throws {
    let root = try makeTree(Self.tree)
    defer { try? FileManager.default.removeItem(at: root) }

    let fromSubdirectory = try runMDLint(["../.."], in: root.appendingPathComponent("docs/sub"))
    let docsOnly = try runMDLint([], in: root.appendingPathComponent("docs"))

    #expect(reportedFiles(fromSubdirectory, under: root) == Self.kept)
    #expect(reportedFiles(docsOnly, under: root) == Self.kept.filter { $0.hasPrefix("docs/") })
  }

  @Test("matches the patterns from the directory of the file given by --config")
  func matchesFromDirectoryOfConfigOption() throws {
    let root = try makeTree([
      "conf/lint.json": "{\"exclude\": [\"docs\"]}",
      "conf/docs/c.md": violating,
      "conf/kept.md": violating,
      "docs/d.md": violating,
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let expected = ["conf/kept.md", "docs/d.md"]

    let relative = try runMDLint(["--config", "conf/lint.json"], in: root)
    let absolute = try runMDLint(
      ["--config", root.appendingPathComponent("conf/lint.json").path], in: root)
    let elsewhere = try runMDLint(
      ["--config", "../conf/lint.json", ".."], in: root.appendingPathComponent("docs"))

    #expect(reportedFiles(relative, under: root) == expected)
    #expect(reportedFiles(absolute, under: root) == expected)
    #expect(reportedFiles(elsewhere, under: root) == expected)
  }

  @Test("skips an excluded file or directory that is named as an argument, without a warning")
  func skipsExcludedArguments() throws {
    let root = try makeTree(Self.tree)
    defer { try? FileManager.default.removeItem(at: root) }

    let excludedOnly = try runMDLint(
      ["--strict", "CHANGELOG.md", "vendor", "vendor/deep/w.md", "docs/draft-1.md"], in: root)
    let mixed = try runMDLint(["--strict", "CHANGELOG.md", "README.md", "vendor/v.md"], in: root)

    #expect(excludedOnly.status == 0)
    #expect(excludedOnly.stderr.isEmpty)
    #expect(excludedOnly.stdout.contains("No rule violations"))
    #expect(mixed.status == 2)
    #expect(mixed.stderr.isEmpty)
    #expect(reportedFiles(mixed, under: root) == ["README.md"])
  }

  @Test("does not fix excluded files")
  func doesNotFixExcludedFiles() throws {
    let root = try makeTree(Self.tree)
    defer { try? FileManager.default.removeItem(at: root) }

    _ = try runMDLint(["--fix", ".", "CHANGELOG.md", "vendor/v.md"], in: root)

    for path in Self.tree.keys where path.hasSuffix(".md") {
      let content = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
      #expect((content == violating) == !Self.kept.contains(path), "\(path)")
    }
  }

  @Test("still reports a missing path that matches exclude")
  func reportsMissingExcludedPath() throws {
    let root = try makeTree(["a.md": violating, ".mdlint.json": "{\"exclude\": [\"gone.md\"]}"])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try runMDLint(["gone.md", "a.md"], in: root)

    #expect(result.status == 1)
    #expect(result.stderr == "error: gone.md: no such file or directory\n")
  }

  @Test("matches a file name whether it is stored composed or decomposed")
  func matchesDecomposedFileName() throws {
    let root = try makeTree([
      ".mdlint.json": "{\"exclude\": [\"ガイド.md\"]}",
      "カ\u{3099}イト\u{3099}.md": violating,
      "a.md": violating,
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(reportedFiles(try runMDLint([], in: root), under: root) == ["a.md"])
  }
}
