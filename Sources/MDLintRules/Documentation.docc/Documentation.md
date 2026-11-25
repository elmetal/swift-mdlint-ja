# ``MDLintRules``

## Overview

The ``MDLintRules`` module contains the built-in linting rules that power swift-mdlint-ja's
Japanese-focused Markdown checks. It bundles ready-to-use rule implementations and
provides helpers for retrieving either the complete default rule set or only the rules
matching a subset of identifiers. Import this module when you need to reference the
individual rules directly or when you want to embed the default configuration in your
own tooling.

The rules check prose only, and they do not look for code themselves. The `Linter` in
`MDLintCore` replaces code blocks, inline code spans, and raw HTML with placeholder
characters before it hands the text to a rule, both when reporting and when fixing. If
you call a rule directly, pass it the text of a `MaskedSource` rather than the raw
Markdown source.

## Topics

### Rule Collections
- ``DefaultRules``

### Markdown Syntax Safeguards
- ``ControlCharacterRule``
- ``HeadingLevelSkipRule``
- ``InlineBacktickClosureRule``
- ``ZeroWidthSpaceRule``

### Japanese Grammar Support
- ``JapaneseParticleDuplicationRule``
- ``JapaneseConjunctionDuplicationRule``

### Japanese Readability Support
- ``JapaneseCommaLimitRule``
- ``SentenceLengthLimitRule``

### Japanese Style Consistency
- ``HalfwidthKanaRule``
- ``HeadingTerminalPunctuationRule``
- ``JapaneseEllipsisRule``
- ``JapaneseEnglishSpacingRule``
- ``JapanesePeriodRule``
- ``JapanesePolitenessStyleConsistencyRule``
- ``RegisteredTermRule``
