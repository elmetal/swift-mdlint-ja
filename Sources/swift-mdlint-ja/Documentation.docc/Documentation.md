# swift-mdlint-ja

@Metadata {
  @TechnologyRoot
}

## Japanese version 
- <doc:Documentation-ja>

## Overview

`swift-mdlint-ja` is a lightweight linter tailored for Japanese Markdown documents. It detects style violations such as inconsistent punctuation or trailing symbols in headings and, when possible, applies automatic fixes. The tool is distributed as a Swift CLI that you can run from `swift run` or by installing the compiled binary.

## Getting Started

Build the command-line tool from the project root:

```bash
swift build -c release
```

After the build completes, either add `.build/release/mdlint-ja` to your `PATH` or run the tool in place with `swift run`.

## Usage

Lint one or more Markdown files or directories. With no arguments, the tool recursively scans all `.md` files under the current working directory.

```bash
mdlint-ja Docs/README.md
mdlint-ja Articles
```

Key options include:

- `--fix` / `-f`: Apply automatic corrections for fixable violations.
- `--format <text|gha>`: Select the output format (`gha` emits GitHub Actions–compatible annotations).
- `--strict`: Exit with code `2` when any violation is detected.
- `--config <path>`: Load a JSON file that lists rule identifiers to enable.

## Configuration

Configuration files express an array of rule identifiers in JSON. Unknown identifiers are reported as warnings on standard error and ignored.

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

## Output

Diagnostics contain the file path, line number, and rule identifier. When `--format gha` is enabled, the output can be pasted directly into GitHub Actions annotations. If `--fix` is provided, files are modified in place when a fix succeeds.

## Topics

### Understanding the Tool

- <doc:HowItWorks>

### Command Options

- <doc:FixOption>
- <doc:FormatOption>
- <doc:StrictOption>
- <doc:ConfigOption>
