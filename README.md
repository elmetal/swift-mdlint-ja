# swift-mdlint-ja
[![Swift Tests](https://github.com/elmetal/swift-mdlint-ja/actions/workflows/swift-test.yml/badge.svg)](https://github.com/elmetal/swift-mdlint-ja/actions/workflows/swift-test.yml)
[![Deploy DocC to GitHub Pages](https://github.com/elmetal/swift-mdlint-ja/actions/workflows/docc-pages.yml/badge.svg)](https://github.com/elmetal/swift-mdlint-ja/actions/workflows/docc-pages.yml)

Minimal Japanese Markdown linter written in Swift.

> [!IMPORTANT]
> This project is experimental and currently under active development.

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
- `--config <path>`: Load a JSON file that chooses the rules and sets their options.
- `--politeness-style <auto|desumasu|dearu>`: Control how the politeness-style consistency rule resolves conflicts. Overrides the configuration file.

When no paths are provided the linter scans the current directory recursively for files with the `.md` extension. Hidden files and directories (such as `.build` or `.git`) are skipped while scanning directories. A path that does not exist is reported as an error: the remaining paths are still linted, and the command exits with status code `1`.

Code blocks, inline code, and raw HTML are excluded from both the checks and `--fix`.

### Turning rules off inside a file

HTML comments turn rules off for part of a file, for both the checks and `--fix`:

```markdown
<!-- mdlint-disable -->
Nothing is reported or fixed here.
<!-- mdlint-enable -->

<!-- mdlint-disable-next-line ja.comma.max-count -->
This line is not checked by the named rule.
```

- `<!-- mdlint-disable -->` turns every rule off from the line of the comment, until `<!-- mdlint-enable -->` or the end of the file.
- `<!-- mdlint-disable-next-line -->` turns every rule off for the line after the comment.
- Rule identifiers after the keyword, separated by spaces or commas, limit a comment to those rules. Unknown identifiers are ignored.

### Configuration file

Without a configuration file, every rule runs with its default settings. A configuration file is JSON in one of two forms.

An object adjusts the default rule set. Rules that are not mentioned keep running:

```json
{
  "rules": {
    "ja.sentence.max-length": { "max": 120 },
    "ja.comma.max-count": { "max": 4, "severity": "error" },
    "ja.kana.no-halfwidth": false
  }
}
```

- `false` turns a rule off, `true` keeps it as it is, and an object sets its options.
- `severity` (`info`, `warning`, or `error`; default `warning`) is accepted by every rule. It changes the label of a violation, not the exit code.
- `max` sets the limit of `ja.comma.max-count` (default `3`) and `ja.sentence.max-length` (default `100`).
- `style` (`auto`, `desumasu`, or `dearu`) sets the style for `ja.style.no-mix-dearu-desumasu`.

An array lists the rules to run, each with its default settings:

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

Unknown rule identifiers and unknown options are ignored after a warning is printed to standard error. A value of the wrong type or out of range stops the command with an error. The former names `ja.comma.max-three` and `ja.sentence.max-one-hundred-characters` are still accepted for `ja.comma.max-count` and `ja.sentence.max-length`.

## Documentation
https://elmetal.github.io/swift-mdlint-ja/documentation/
