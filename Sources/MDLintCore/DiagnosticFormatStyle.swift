import Foundation

/// A format style that converts a ``Diagnostic`` into a presentable value.
///
/// Conform to ``DiagnosticFormatStyle`` to customize how diagnostics appear in
/// user interfaces, command-line output, or continuous integration logs. Each
/// conforming type specifies a ``FormatStyle/FormatOutput`` that best suits its
/// destination and implements ``FormatStyle/format(_:)`` to render the
/// diagnostic.
///
/// The Markdown linter provides built-in styles such as ``TextDiagnosticFormatStyle``
/// for human-readable output and ``GHADiagnosticFormatStyle`` for GitHub Actions
/// annotations. You can add additional styles to target other tools or reporting
/// formats.
public protocol DiagnosticFormatStyle: FormatStyle where FormatInput == Diagnostic {}
