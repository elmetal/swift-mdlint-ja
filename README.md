# swift-mdlint-ja

Minimal Japanese Markdown linter written in Swift.

## Getting Started

```bash
swift build
```

## Usage

Run the linter against one or more Markdown files or directories:

```bash
swift run mdlint-ja README.md Docs/
```

Key options:

- `--fix` / `-f`: Apply available automatic fixes in place.
- `--format <text|gha>`: Choose plain text output (default) or GitHub Actions format.
- `--strict`: Exit with a non-zero status code when violations are detected.

When no paths are provided the linter scans the current directory recursively for files with the `.md` extension.

