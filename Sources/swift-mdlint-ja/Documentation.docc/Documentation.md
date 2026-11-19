# swift-mdlint-ja

@Metadata {
  @TechnologyRoot
}

## Overview

`swift-mdlint-ja` is a lightweight linter tailored for Japanese Markdown documents. It detects style violations such as inconsistent punctuation or trailing symbols in headings and, when possible, applies automatic fixes. The tool is distributed as a Swift CLI that you can run from `swift run` or by installing the compiled binary.

## Getting Started

Build the command-line tool from the project root:

```bash
swift build -c release
```

After the build completes, either add `.build/release/mdlint-ja` to your `PATH` or run the tool in place with `swift run`.

## Usage

Lint one or more Markdown files or directories. With no arguments, the tool recursively scans all `.md` files under the current working directory. Hidden files and directories (such as `.build` or `.git`) are skipped while scanning directories. Code blocks, inline code, and raw HTML are excluded from both the checks and the automatic fixes.

```bash
mdlint-ja Docs/README.md
mdlint-ja Articles
```

Key options include:

- `--fix` / `-f`: Apply automatic corrections for fixable violations.
- `--format <text|gha>`: Select the output format (`gha` emits GitHub Actions–compatible annotations).
- `--strict`: Exit with code `2` when any violation is detected.
- `--config <path>`: Load a JSON file that lists rule identifiers to enable.
- `--politeness-style <auto|desumasu|dearu>`: Choose the style that the politeness-style consistency rule enforces (`auto` follows the majority style of each document).

A path that does not exist is reported as an error. The remaining paths are still linted, and the command then exits with code `1`.

## Configuration

Configuration files express an array of rule identifiers in JSON. Unknown identifiers are reported as warnings on standard error and ignored.

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

## Turning rules off inside a file

HTML comments turn rules off for part of a file. Each comment applies to every rule, or to the rule identifiers written after the keyword. See <doc:DisableComments> for the details.

```markdown
<!-- mdlint-disable -->
Nothing is reported or fixed here.
<!-- mdlint-enable -->

<!-- mdlint-disable-next-line ja.comma.max-three -->
This line is not checked by the named rule.
```

## Output

Diagnostics contain the file path, line number, and a message; the `text` format also shows the rule identifier. When `--format gha` is enabled, the output uses GitHub Actions workflow commands so violations appear as annotations. If `--fix` is provided, files are modified in place and only the violations that remain afterwards are reported.

## Topics

### Japanese Version
- <doc:Documentation-ja>

### Understanding the Tool

- <doc:HowItWorks>
- <doc:DisableComments>

### Command Options

- <doc:FixOption>
- <doc:FormatOption>
- <doc:StrictOption>
- <doc:ConfigOption>
