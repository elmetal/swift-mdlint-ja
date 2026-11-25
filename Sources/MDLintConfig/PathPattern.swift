/// A pattern that selects files and directories by their path.
///
/// A pattern is a relative path whose components are separated by `/`. Three
/// wildcards are supported:
///
/// - `*` matches any number of characters within one path component.
/// - `?` matches exactly one character within one path component.
/// - `**` as a whole path component matches any number of components,
///   including none.
///
/// Every other character matches itself, and case matters. There are no
/// character classes and there is no way to escape a wildcard.
///
/// A pattern is matched from the first component of the path, so `notes.md`
/// selects `notes.md` but not `docs/notes.md`; write `**/notes.md` for a file
/// at any depth. A pattern that selects a directory also selects everything
/// inside it.
///
/// Characters are compared the way `String` compares them, so a name matches
/// whether it is stored in composed or decomposed form (`が` as one or as two
/// Unicode scalars).
public struct PathPattern: Equatable, Sendable, CustomStringConvertible {
  private enum Token: Equatable, Sendable {
    /// `*`
    case anyCharacters
    /// `?`
    case anyCharacter
    case literal(Character)
  }

  private enum Component: Equatable, Sendable {
    /// `**`
    case anyDirectories
    case name([Token])
  }

  /// The pattern as it was written.
  public let description: String

  private let components: [Component]

  /// Creates a pattern.
  ///
  /// - Returns: `nil` when the pattern is empty, starts with `/`, or has a
  ///   `..` component. Such a pattern cannot name a path below the directory
  ///   it is relative to.
  public init?(_ pattern: String) {
    guard !pattern.hasPrefix("/") else { return nil }

    var components: [Component] = []
    for component in pattern.split(separator: "/") {
      switch component {
      case ".": continue
      case "..": return nil
      case "**": components.append(.anyDirectories)
      default:
        components.append(
          .name(
            component.map { character in
              switch character {
              case "*": .anyCharacters
              case "?": .anyCharacter
              default: .literal(character)
              }
            }))
      }
    }
    guard !components.isEmpty else { return nil }

    self.description = pattern
    self.components = components
  }

  /// Returns whether the pattern selects the path or a directory above it.
  ///
  /// - Parameter relativePath: A path with `/` between its components,
  ///   relative to the directory that the pattern is relative to.
  public func matches(_ relativePath: String) -> Bool {
    matches(pathComponents: relativePath.split(separator: "/").map(String.init))
  }

  func matches(pathComponents: some Collection<String>) -> Bool {
    Self.matches(components[...], pathComponents.map(Array.init)[...])
  }

  private static func matches(_ pattern: ArraySlice<Component>, _ path: ArraySlice<[Character]>)
    -> Bool
  {
    guard let first = pattern.first else {
      // The whole pattern is used up. What is left of the path lies inside a
      // directory that the pattern selects.
      return true
    }
    let rest = pattern.dropFirst()

    switch first {
    case .anyDirectories:
      return (0...path.count).contains { matches(rest, path.dropFirst($0)) }
    case .name(let tokens):
      guard let name = path.first, matches(tokens, name) else { return false }
      return matches(rest, path.dropFirst())
    }
  }

  /// Matches one path component against the wildcards of one pattern
  /// component.
  private static func matches(_ tokens: [Token], _ name: [Character]) -> Bool {
    var tokenIndex = 0
    var nameIndex = 0
    // Where to resume when the characters after the last `*` do not match:
    // the `*` then takes one more character.
    var resumePoint: (tokenIndex: Int, nameIndex: Int)?

    while nameIndex < name.count {
      if tokenIndex < tokens.count, tokens[tokenIndex] == .anyCharacters {
        resumePoint = (tokenIndex + 1, nameIndex)
        tokenIndex += 1
      } else if tokenIndex < tokens.count,
        tokens[tokenIndex] == .anyCharacter || tokens[tokenIndex] == .literal(name[nameIndex])
      {
        tokenIndex += 1
        nameIndex += 1
      } else if let point = resumePoint {
        tokenIndex = point.tokenIndex
        nameIndex = point.nameIndex + 1
        resumePoint = (point.tokenIndex, point.nameIndex + 1)
      } else {
        return false
      }
    }
    return tokens[tokenIndex...].allSatisfy { $0 == .anyCharacters }
  }
}
