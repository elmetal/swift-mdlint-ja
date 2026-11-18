import Markdown

extension Document {
  /// The 1-based numbers of the source lines that belong to fenced or indented
  /// code blocks, fence lines included.
  ///
  /// Rules that check Japanese prose use this to leave code alone. Code blocks
  /// nested in lists and block quotes are included.
  var codeBlockLineNumbers: Set<Int> {
    var lineNumbers: Set<Int> = []

    func visit(_ markup: Markup) {
      for child in markup.children {
        if let codeBlock = child as? CodeBlock {
          if let range = codeBlock.range {
            lineNumbers.formUnion(range.lowerBound.line...range.upperBound.line)
          }
        } else if child is BlockMarkup {
          visit(child)
        }
      }
    }

    visit(self)
    return lineNumbers
  }
}
