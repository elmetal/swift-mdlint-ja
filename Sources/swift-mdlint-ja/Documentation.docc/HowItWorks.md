# How ``swift-mdlint-ja`` Works

Learn how the command-line interface orchestrates rule loading, lint execution, and output formatting.

## Command-line entry point

The executable is defined by the `MDLintCommand` type, which uses `ArgumentParser` to expose the `mdlint-ja` command. The tool accepts Markdown file paths or directories to lint and offers options to apply automatic fixes (`--fix`), select a diagnostic format (`--format text|gha`), enable strict exit codes (`--strict`), point to a JSON configuration file (`--config`), and choose the preferred politeness style (`--politeness-style auto|desumasu|dearu`).

## Loading lint rules

When the command starts it creates a `RuleConfigurationLoader`. The loader reads the optional configuration file to determine which rules from `MDLintRules` should be active. Unknown identifiers are reported to standard error but are otherwise ignored so that linting can continue.

## Resolving inputs

If no paths are provided, the current working directory is scanned. Otherwise, each path is resolved and any Markdown file (`.md`) is collected. Directories are traversed recursively to make sure nested documentation is linted alongside individual files that are explicitly specified; hidden files and directories such as `.build` or `.git` are skipped during traversal. A file reached through several arguments is linted once, and paths that do not exist or cannot be read as UTF-8 are skipped with a warning on standard error.

## Running the linter

All collected files are processed by a `Linter` from `MDLintCore`. The linter returns diagnostics and, when `--fix` is enabled, the fixed content. Fixable violations are written back to disk whenever the fixes differ from the original text.

## Excluding code and HTML

Rules check prose only. Before running the rules, the linter parses the file and replaces the following regions with placeholder characters:

- Fenced and indented code blocks
- Inline code spans
- HTML blocks and inline HTML, including comments

Each hidden character becomes exactly one placeholder, so reported line and column numbers still match the file. The same masked text is handed to the automatic fixes, and the hidden regions are restored afterwards, which means `--fix` never rewrites code or HTML. Link destinations and front matter are not hidden.

Inline code and inline HTML stay part of the sentence around them, but their characters do not count toward the sentence-length limit: like URLs, they are often long without making the sentence harder to read.

## Reporting diagnostics

Diagnostics are sorted for stable output before being printed. Two output formats are supported:

- `text`: a human-readable listing that mirrors common command-line linters.
- `gha`: a format tailored for GitHub Actions so annotations appear directly in workflow logs.

When the `--strict` flag is supplied the process exits with status code `2` if any diagnostics were emitted, allowing continuous integration pipelines to fail the build on lint violations.
