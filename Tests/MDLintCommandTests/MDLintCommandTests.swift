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
}
