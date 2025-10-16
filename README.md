# swift-mdlint-ja
[![Swift Tests](https://github.com/elmetal/swift-mdlint-ja/actions/workflows/swift-test.yml/badge.svg)](https://github.com/elmetal/swift-mdlint-ja/actions/workflows/swift-test.yml)

Minimal Japanese Markdown linter written in Swift.

## Getting Started

```bash
swift build
```

## Usage

Run the linter against one or more Markdown files or directories:

```bash
mdlint-ja Sample.md
```

Key options:

- `--fix` / `-f`: Apply available automatic fixes in place.
- `--format <text|gha>`: Choose plain text output (default) or GitHub Actions format.
- `--strict`: Exit with a non-zero status code when violations are detected.
- `--config <path>`: Load a JSON file that lists the rule identifiers to enable.

When no paths are provided the linter scans the current directory recursively for files with the `.md` extension.

### Configuration file

The configuration file is a JSON array containing rule identifier strings. Unknown identifiers are ignored.

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

