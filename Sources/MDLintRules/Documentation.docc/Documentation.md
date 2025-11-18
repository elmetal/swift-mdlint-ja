# ``MDLintRules``

## Overview

The ``MDLintRules`` module contains the built-in linting rules that power SwiftMDLint's
Japanese-focused Markdown checks. It bundles ready-to-use rule implementations and
provides helpers for retrieving either the complete default rule set or only the rules
matching a subset of identifiers. Import this module when you need to reference the
individual rules directly or when you want to embed the default configuration in your
own tooling.

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
