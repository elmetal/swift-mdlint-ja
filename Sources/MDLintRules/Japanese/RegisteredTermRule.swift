import Foundation
import MDLintCore
import Markdown

/// A rule that keeps the spelling of registered terms consistent.
///
/// The rule has no terms of its own. Each ``Term`` it is given names one
/// expected spelling and the variants to replace with it, such as "サーバー"
/// with the variant "サーバ". Every occurrence of a variant in prose is
/// reported with a fix-it that replaces it with the expected spelling. Without
/// terms the rule reports nothing.
///
/// Spellings are compared character by character, so the comparison is
/// case-sensitive and a variant matches anywhere, also inside a longer word.
/// Each line is scanned from left to right:
///
/// - Where several registered spellings start at the same character, the
///   longest one is taken. The expected spellings take part in this, so
///   "サーバ" is not reported inside "サーバー", and a term without variants
///   keeps a longer word such as "ユーザビリティ" from matching "ユーザ".
/// - The scan continues after the spelling it took, so a spelling that
///   starts inside it is not considered.
/// - A variant that lies inside an occurrence of its own expected spelling
///   is never reported, wherever the scan found it.
///
/// The linter hides code and raw HTML before the rule runs. The rule itself
/// leaves URLs and the destinations of links, images, and link reference
/// definitions alone, because rewriting them would break the link.
public struct RegisteredTermRule: Rule {
  /// A term with the spelling to use and the spellings to replace.
  public struct Term: Hashable, Sendable {
    /// The spelling that the term should have.
    public var expected: String
    /// The spellings that are replaced by ``expected``. A term without
    /// variants only protects its expected spelling from the variants of
    /// shorter terms.
    public var variants: [String]

    public init(expected: String, variants: [String] = []) {
      self.expected = expected
      self.variants = variants
    }
  }

  /// A reason why a list of terms cannot be used as it is.
  public enum TermError: Error, Hashable, Sendable {
    /// A spelling is empty, or contains a line break or a placeholder
    /// character of `MaskedSource`. `termIndex` is the position of its term
    /// in the list.
    case unusableSpelling(String, termIndex: Int)
    /// A spelling is the expected spelling of one term and a variant of the
    /// same or another term.
    case expectedAndVariant(String)
    /// A spelling is a variant of terms with different expected spellings.
    case variantOfSeveralTerms(String, expected: [String])
  }

  public let id = "ja.term.prefer-registered"
  public let description = "登録した用語は、登録した表記に統一してください。"

  /// The terms the rule was created with.
  public let terms: [Term]

  /// The usable spellings of ``terms`` grouped by their first character,
  /// longest first.
  private let spellings: [Character: [Spelling]]
  private let hasVariants: Bool

  /// Creates a rule that reports the variants of the given terms.
  ///
  /// Call ``validate(_:)`` first to find mistakes in terms that come from a
  /// user. The rule skips what `validate(_:)` rejects: unusable spellings, a
  /// variant that is also an expected spelling, and a variant that an
  /// earlier term already lists.
  public init(terms: [Term] = []) {
    self.terms = terms

    let usableTerms = terms.filter { Self.isUsable($0.expected) }
    let expectedSpellings = Set(usableTerms.map(\.expected))
    var registered: Set<String> = []
    var spellings: [Spelling] = []

    for term in usableTerms {
      let expected = Array(term.expected)
      if registered.insert(term.expected).inserted {
        spellings.append(Spelling(characters: expected, replacement: nil))
      }
      for variant in term.variants
      where Self.isUsable(variant) && !expectedSpellings.contains(variant)
        && registered.insert(variant).inserted
      {
        let characters = Array(variant)
        let lastOffset = expected.count - characters.count
        spellings.append(
          Spelling(
            characters: characters,
            replacement: Replacement(
              expected: term.expected,
              expectedCharacters: expected,
              offsetsInExpected: lastOffset < 0
                ? []
                : (0...lastOffset).filter { expected[$0...].starts(with: characters) })))
      }
    }

    self.hasVariants = spellings.contains { $0.replacement != nil }
    self.spellings = Dictionary(grouping: spellings, by: { $0.characters[0] })
      .mapValues { $0.sorted { $0.characters.count > $1.characters.count } }
  }

  /// Checks that every spelling can be used and that no spelling has two
  /// roles.
  ///
  /// A term may have no variants, several terms may share an expected
  /// spelling, and a variant may be repeated under one expected spelling.
  ///
  /// - Throws: The first ``TermError`` found, in the order of the list.
  public static func validate(_ terms: [Term]) throws {
    for (index, term) in terms.enumerated() {
      for spelling in [term.expected] + term.variants where !isUsable(spelling) {
        throw TermError.unusableSpelling(spelling, termIndex: index)
      }
    }

    let expectedSpellings = Set(terms.map(\.expected))
    var expectedByVariant: [String: String] = [:]
    for term in terms {
      for variant in term.variants {
        if expectedSpellings.contains(variant) {
          throw TermError.expectedAndVariant(variant)
        }
        if let other = expectedByVariant[variant], other != term.expected {
          throw TermError.variantOfSeveralTerms(variant, expected: [other, term.expected])
        }
        expectedByVariant[variant] = term.expected
      }
    }
  }

  public func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic] {
    guard hasVariants else { return [] }
    var diagnostics: [Diagnostic] = []

    for (lineIndex, line) in originalText.sourceLines.enumerated() {
      let characters = Array(line)
      // Only looked for on the lines that have a variant.
      var linkTargets: [Range<Int>]?

      var index = 0
      while index < characters.count {
        guard let spelling = longestSpelling(in: characters, at: index) else {
          index += 1
          continue
        }
        let range = index..<(index + spelling.characters.count)
        index = range.upperBound

        guard let replacement = spelling.replacement,
          !replacement.covers(range, in: characters)
        else { continue }

        let targets = linkTargets ?? Self.linkTargets(in: characters)
        linkTargets = targets
        guard !targets.contains(where: { $0.overlaps(range) }) else { continue }

        let variant = String(spelling.characters)
        diagnostics.append(
          Diagnostic(
            file: fileURL,
            line: lineIndex + 1,
            column: range.lowerBound + 1,
            ruleID: id,
            message: "「\(variant)」は「\(replacement.expected)」と表記してください。",
            severity: .warning,
            fixIt: FixIt(
              description: "「\(variant)」を「\(replacement.expected)」に置換",
              line: lineIndex + 1,
              column: range.lowerBound + 1,
              endLine: lineIndex + 1,
              endColumn: range.upperBound + 1,
              replacement: replacement.expected)))
      }
    }

    return diagnostics
  }
}

// MARK: - Matching

extension RegisteredTermRule {
  /// A registered spelling, expected or variant.
  private struct Spelling: Sendable {
    let characters: [Character]
    /// What a variant is replaced with. `nil` for an expected spelling.
    let replacement: Replacement?
  }

  private struct Replacement: Sendable, Equatable {
    let expected: String
    let expectedCharacters: [Character]
    /// The offsets at which the variant occurs inside the expected spelling.
    let offsetsInExpected: [Int]

    /// Whether the variant found at `range` of `line` is part of an
    /// occurrence of the expected spelling.
    func covers(_ range: Range<Int>, in line: [Character]) -> Bool {
      offsetsInExpected.contains { offset in
        let start = range.lowerBound - offset
        return start >= 0 && line[start...].starts(with: expectedCharacters)
      }
    }
  }

  private func longestSpelling(in line: [Character], at index: Int) -> Spelling? {
    spellings[line[index]]?.first { line[index...].starts(with: $0.characters) }
  }

  /// Whether a spelling can be searched for and written into a line.
  private static func isUsable(_ spelling: String) -> Bool {
    !spelling.isEmpty
      && !spelling.contains(where: \.isLineTerminator)
      && !spelling.unicodeScalars.contains {
        $0 == MaskedSource.inlinePlaceholder.unicodeScalars.first
          || $0 == MaskedSource.blockPlaceholder.unicodeScalars.first
      }
  }
}

// MARK: - Link targets

extension RegisteredTermRule {
  /// Returns the parts of a line, as character offsets, that say where a
  /// link goes rather than what the reader sees.
  ///
  /// These are URLs, what is between the parentheses of an inline link or
  /// image (the title included), and what follows the label of a link
  /// reference definition.
  private static func linkTargets(in line: [Character]) -> [Range<Int>] {
    var targets: [Range<Int>] = []

    let text = String(line)
    for range in SentenceLengthLimitRule.urlRanges(in: text) {
      let start = text.distance(from: text.startIndex, to: range.lowerBound)
      targets.append(start..<(start + text.distance(from: range.lowerBound, to: range.upperBound)))
    }

    // `](destination)`, with balanced parentheses inside the destination.
    var index = 0
    while index + 1 < line.count {
      guard line[index] == "]", line[index + 1] == "(" else {
        index += line[index] == "\\" ? 2 : 1
        continue
      }
      let start = index + 2
      var depth = 1
      var end = start
      while end < line.count, depth > 0 {
        switch line[end] {
        case "\\": end += 1
        case "(": depth += 1
        case ")": depth -= 1
        default: break
        }
        end += 1
      }
      guard depth == 0, end <= line.count else {
        index = start
        continue
      }
      targets.append(start..<(end - 1))
      index = end
    }

    // `[label]: destination`, indented by up to three spaces. `[^label]:`
    // starts a footnote, which is prose.
    let indentation = line.prefix { $0 == " " }.count
    if indentation <= 3, line.dropFirst(indentation).first == "[",
      line.dropFirst(indentation + 1).first != "^",
      let labelEnd = line.firstIndex(of: "]"),
      labelEnd + 1 < line.count, line[labelEnd + 1] == ":"
    {
      targets.append((labelEnd + 2)..<line.count)
    }

    return targets
  }
}
