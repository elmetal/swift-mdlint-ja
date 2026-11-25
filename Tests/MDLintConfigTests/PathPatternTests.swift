import Foundation
import MDLintCore
import Testing

@testable import MDLintConfig

@Suite("PathPattern")
struct PathPatternTests {
  @Test(
    "matches a path from its first component",
    arguments: [
      ("CHANGELOG.md", "CHANGELOG.md", true),
      ("CHANGELOG.md", "docs/CHANGELOG.md", false),
      ("CHANGELOG.md", "changelog.md", false),
      ("CHANGELOG.md", "CHANGELOG.md.bak", false),
      ("docs/notes.md", "docs/notes.md", true),
      ("docs/notes.md", "notes.md", false),
      ("docs/notes.md", "src/docs/notes.md", false),
      ("./docs//notes.md", "docs/notes.md", true),
      ("docs/notes.md/", "docs/notes.md", true),
    ])
  func matchesFromFirstComponent(pattern: String, path: String, expected: Bool) throws {
    #expect(try #require(PathPattern(pattern)).matches(path) == expected)
  }

  @Test(
    "matches any characters within one component for *",
    arguments: [
      ("*.md", "a.md", true),
      ("*.md", ".md", true),
      ("*.md", "a.txt", false),
      ("*.md", "docs/a.md", false),
      ("docs/*.md", "docs/a.md", true),
      ("docs/*.md", "docs/sub/a.md", false),
      ("*/a.md", "docs/a.md", true),
      ("*/a.md", "a.md", false),
      ("*/a.md", "docs/sub/a.md", false),
      ("draft-*-v*.md", "draft-guide-v2.md", true),
      ("draft-*-v*.md", "draft--v.md", true),
      ("draft-*-v*.md", "draft-guide.md", false),
      ("*a*b", "xaxaxb", true),
      ("*a*b", "xaxax", false),
      ("a*", "a", true),
      ("*", "anything.md", true),
      ("a***b.md", "a-b.md", true),
    ])
  func matchesStar(pattern: String, path: String, expected: Bool) throws {
    #expect(try #require(PathPattern(pattern)).matches(path) == expected)
  }

  @Test(
    "matches exactly one character for ?",
    arguments: [
      ("v?.md", "v1.md", true),
      ("v?.md", "v.md", false),
      ("v?.md", "v10.md", false),
      ("v?.md", "v/.md", false),
      ("第?章.md", "第一章.md", true),
      ("第?章.md", "第十一章.md", false),
      ("??", "ab", true),
      ("??", "a", false),
      ("?*", "", false),
    ])
  func matchesQuestionMark(pattern: String, path: String, expected: Bool) throws {
    #expect(try #require(PathPattern(pattern)).matches(path) == expected)
  }

  @Test(
    "matches any number of components for **",
    arguments: [
      ("vendor/**", "vendor/a.md", true),
      ("vendor/**", "vendor/deep/er/a.md", true),
      ("vendor/**", "vendor", true),
      ("vendor/**", "vendors/a.md", false),
      ("vendor/**", "src/vendor/a.md", false),
      ("**/CHANGELOG.md", "CHANGELOG.md", true),
      ("**/CHANGELOG.md", "docs/CHANGELOG.md", true),
      ("**/CHANGELOG.md", "a/b/c/CHANGELOG.md", true),
      ("**/CHANGELOG.md", "a/CHANGELOG.md.bak", false),
      ("docs/**/old/*.md", "docs/old/a.md", true),
      ("docs/**/old/*.md", "docs/2024/q1/old/a.md", true),
      ("docs/**/old/*.md", "docs/2024/a.md", false),
      ("**/node_modules/**", "web/node_modules/pkg/README.md", true),
      ("**/node_modules/**", "web/modules/pkg/README.md", false),
      ("**/a/**/b/**", "a/x/a/y/b/c.md", true),
      ("**", "a/b.md", true),
    ])
  func matchesDoubleStar(pattern: String, path: String, expected: Bool) throws {
    #expect(try #require(PathPattern(pattern)).matches(path) == expected)
  }

  @Test(
    "selects everything inside a directory it matches",
    arguments: [
      ("vendor", "vendor/a.md", true),
      ("vendor/", "vendor/deep/a.md", true),
      ("docs/*", "docs/sub/a.md", true),
      ("docs/draft-*", "docs/draft-2024/a.md", true),
      ("**/archive", "docs/archive/2020/a.md", true),
      ("vendor", "vendor.md", false),
      ("vendor", "src/vendor/a.md", false),
    ])
  func selectsContentsOfDirectory(pattern: String, path: String, expected: Bool) throws {
    #expect(try #require(PathPattern(pattern)).matches(path) == expected)
  }

  @Test("treats every other character as itself")
  func treatsOtherCharactersLiterally() throws {
    #expect(try #require(PathPattern("[ab].md")).matches("[ab].md"))
    #expect(try #require(PathPattern("[ab].md")).matches("a.md") == false)
    #expect(try #require(PathPattern("a{1,2}.md")).matches("a{1,2}.md"))
    #expect(try #require(PathPattern("a\\*.md")).matches("a\\x.md"))
    #expect(try #require(PathPattern("a.md")).matches("abmd") == false)
  }

  @Test("matches a name in composed and in decomposed form")
  func matchesCanonicallyEquivalentNames() throws {
    let composed = "ガイド.md"
    let decomposed = "カ\u{3099}イト\u{3099}.md"
    #expect(composed.unicodeScalars.count != decomposed.unicodeScalars.count)

    #expect(try #require(PathPattern(composed)).matches(decomposed))
    #expect(try #require(PathPattern(decomposed)).matches(composed))
    #expect(try #require(PathPattern("ガ??.md")).matches(decomposed))
    #expect(try #require(PathPattern("*ド.md")).matches(decomposed))
  }

  @Test(
    "rejects a pattern that cannot name a path below its directory",
    arguments: ["", "/", "/vendor/**", "..", "../vendor", "docs/../vendor", ".", "./", "//"])
  func rejectsInvalidPattern(pattern: String) {
    #expect(PathPattern(pattern) == nil)
  }

  @Test("keeps the pattern as it was written")
  func keepsPatternText() throws {
    #expect(try #require(PathPattern("./vendor/**/")).description == "./vendor/**/")
  }
}

@Suite("LintConfiguration")
struct LintConfigurationTests {
  private func configuration(_ patterns: [String], in directory: String?) throws
    -> LintConfiguration
  {
    LintConfiguration(
      rules: [],
      excludePatterns: try patterns.map { try #require(PathPattern($0)) },
      directoryURL: directory.map { URL(fileURLWithPath: $0, isDirectory: true) })
  }

  @Test("matches the patterns against paths relative to its directory")
  func matchesRelativeToDirectory() throws {
    let configuration = try configuration(["vendor/**", "CHANGELOG.md"], in: "/work/project")

    #expect(configuration.excludes(URL(fileURLWithPath: "/work/project/vendor/a.md")))
    #expect(configuration.excludes(URL(fileURLWithPath: "/work/project/vendor/b/a.md")))
    #expect(configuration.excludes(URL(fileURLWithPath: "/work/project/vendor")))
    #expect(configuration.excludes(URL(fileURLWithPath: "/work/project/CHANGELOG.md")))
    #expect(!configuration.excludes(URL(fileURLWithPath: "/work/project/docs/CHANGELOG.md")))
    #expect(!configuration.excludes(URL(fileURLWithPath: "/work/project/README.md")))
  }

  @Test("looks through . and .. in the path of the file")
  func standardizesFilePath() throws {
    let configuration = try configuration(["vendor/**"], in: "/work/project/docs/..")

    #expect(configuration.excludes(URL(fileURLWithPath: "/work/project/./docs/../vendor/a.md")))
    #expect(!configuration.excludes(URL(fileURLWithPath: "/work/project/vendor/../a.md")))
  }

  @Test("never excludes a path outside its directory")
  func keepsPathsOutsideDirectory() throws {
    let configuration = try configuration(["**", "vendor"], in: "/work/project")

    #expect(!configuration.excludes(URL(fileURLWithPath: "/work/other/vendor/a.md")))
    #expect(!configuration.excludes(URL(fileURLWithPath: "/work/project-2/a.md")))
    #expect(!configuration.excludes(URL(fileURLWithPath: "/vendor/a.md")))
    #expect(!configuration.excludes(URL(fileURLWithPath: "/work/project")))
    #expect(configuration.excludes(URL(fileURLWithPath: "/work/project/a.md")))
  }

  @Test("matches from the root when its directory is the root")
  func matchesFromRootDirectory() throws {
    let configuration = try configuration(["vendor"], in: "/")

    #expect(configuration.excludes(URL(fileURLWithPath: "/vendor/a.md")))
    #expect(!configuration.excludes(URL(fileURLWithPath: "/work/vendor/a.md")))
  }

  @Test("excludes nothing without patterns or without a directory")
  func excludesNothingByDefault() throws {
    let file = URL(fileURLWithPath: "/work/project/a.md")

    #expect(!LintConfiguration(rules: []).excludes(file))
    #expect(try !configuration([], in: "/work/project").excludes(file))
    #expect(try !configuration(["**"], in: nil).excludes(file))
  }
}
