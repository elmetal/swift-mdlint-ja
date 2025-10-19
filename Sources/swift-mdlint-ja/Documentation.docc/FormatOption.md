# Formatting diagnostics from ``swift-mdlint-ja``

Learn how the `--format` option shapes diagnostic output.

## Overview

`mdlint-ja` produces human-readable diagnostics by default. Supplying `--format` lets you switch between the standard `text` output and a GitHub Actions–friendly `gha` style.

## Usage

```bash
mdlint-ja --format text Docs
mdlint-ja --format gha Docs
```

- The option accepts only two values: `text` (default) and `gha`.
- The comparison is case-insensitive, so `--format GHA` yields the same result as `--format gha`.

## When to use each format

- **text**: Ideal for local development and continuous integration logs where human-readable output is preferred.
- **gha**: Emits lines that GitHub Actions interprets as workflow annotations, making it easy to surface lint issues inline in pull requests.
