import Foundation
import MDLintCore

let sampleFileURL = URL(fileURLWithPath: "/tmp/rules.md")

// Rules rely on the linter to hide code and raw HTML from them, so a test whose
// input contains either runs its rule through these helpers instead of handing
// the raw text to the rule.

extension Rule {
  /// Checks `content` the way ``Linter`` does, with code and raw HTML hidden from the rule.
  func diagnostics(for content: String) -> [Diagnostic] {
    Linter(rules: [self]).lint(content: content, fileURL: sampleFileURL, applyFixes: false).0
  }
}

extension Rule {
  /// Applies the rule's fix-its to `content` the way ``Linter`` does, with code and raw HTML
  /// hidden from the rule.
  func fixed(_ content: String) -> String? {
    Linter(rules: [self]).lint(content: content, fileURL: sampleFileURL, applyFixes: true).1
  }
}
