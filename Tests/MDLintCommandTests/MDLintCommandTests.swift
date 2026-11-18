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
    let root = try makeTree(["sub/s.md": "これはテストです...\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let once = try runMDLint(["sub/s.md"], in: root)
    let repeated = try runMDLint([".", "sub/s.md", "sub", "./sub/../sub/s.md"], in: root)

    let onceLines = once.stdout.split(separator: "\n")
    let repeatedLines = repeated.stdout.split(separator: "\n")
    #expect(!onceLines.isEmpty)
    #expect(!once.stdout.contains("No rule violations"))
    #expect(repeatedLines.count == onceLines.count)
  }

  @Test("warns about a path that does not exist and lints the rest")
  func warnsAboutMissingPath() throws {
    let root = try makeTree(["a.md": "これはテストです...\n"])
    defer { try? FileManager.default.removeItem(at: root) }

    let baseline = try runMDLint(["a.md"], in: root)
    let result = try runMDLint(["typo.md", "a.md"], in: root)

    #expect(baseline.stderr.isEmpty)
    #expect(result.stderr == "warning: Skipping typo.md: no such file or directory\n")
    #expect(result.stdout == baseline.stdout)
    #expect(result.status == baseline.status)
  }

  @Test("warns about a file that is not valid UTF-8 and lints the rest")
  func warnsAboutNonUTF8File() throws {
    let root = try makeTree(["a.md": "これはテストです...\n"])
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
    let original = "これはテストです...\n"
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
    let original = "これはテストです...\n"
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
}
