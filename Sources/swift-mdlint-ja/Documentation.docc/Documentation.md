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
- `--config <path>`: Load a JSON file that chooses the rules, sets their options, and excludes files. Without it, the nearest `.mdlint.json` in the current directory or its parents is used.
- `--no-config`: Do not look for `.mdlint.json`.
- `--politeness-style <auto|desumasu|dearu>`: Choose the style that the politeness-style consistency rule enforces (`auto` follows the majority style of each document). It takes precedence over the configuration file.

A path that does not exist is reported as an error. The remaining paths are still linted, and the command then exits with code `1`.

## Configuration

A configuration file is JSON. Name it `.mdlint.json` and put it at the top of your project: when `--config` is not given, the command uses the first `.mdlint.json` it finds in the current working directory or its parent directories. Without a configuration file, every rule runs with its default settings.

An object with a `rules` key adjusts the default rule set: `false` turns a rule off, and an object sets its options. Rules that the file does not mention keep running with their default settings. An `exclude` key lists patterns of files to leave out, relative to the directory of the configuration file.

```json
{
  "exclude": ["vendor/**", "CHANGELOG.md"],
  "rules": {
    "ja.sentence.max-length": { "max": 120 },
    "ja.comma.max-count": { "max": 4, "severity": "error" },
    "ja.kana.no-halfwidth": false
  }
}
```

An array of rule identifiers runs only the listed rules, each with its default settings.

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

Unknown identifiers and unknown options are reported as warnings on standard error and ignored. See <doc:ConfigOption> for the options of each rule, the pattern syntax of `exclude`, and how the configuration file is found. The options include the `terms` of `ja.term.prefer-registered`, the rule that replaces the variants of the terms you register (`サーバ` with `サーバー`, for example).

## Turning rules off inside a file

HTML comments turn rules off for part of a file. Each comment applies to every rule, or to the rule identifiers written after the keyword. See <doc:DisableComments> for the details.

```markdown
<!-- mdlint-disable -->
Nothing is reported or fixed here.
<!-- mdlint-enable -->

<!-- mdlint-disable-next-line ja.comma.max-count -->
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
