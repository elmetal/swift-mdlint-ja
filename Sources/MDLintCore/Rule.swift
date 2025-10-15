import Foundation
import Markdown

public protocol Rule {
    var id: String { get }
    var description: String { get }
    func check(document: Document, fileURL: URL, originalText: String) -> [Diagnostic]
}

public protocol AutoFixable {
    /// Returns a new Markdown text with the violations fixed.
    func fixing(originalText: String) -> String
}
