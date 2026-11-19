# How ``swift-mdlint-ja`` Works

Learn how the command-line interface orchestrates rule loading, lint execution, and output formatting.

## Command-line entry point

The executable is defined by the `MDLintCommand` type, which uses `ArgumentParser` to expose the `mdlint-ja` command. The tool accepts Markdown file paths or directories to lint and offers options to apply automatic fixes (`--fix`), select a diagnostic format (`--format text|gha`), enable strict exit codes (`--strict`), point to a JSON configuration file (`--config`), and choose the preferred politeness style (`--politeness-style auto|desumasu|dearu`).

## Loading lint rules

When the command starts it creates a `RuleConfigurationLoader`. The loader reads the optional configuration file to determine which rules from `MDLintRules` should be active and with which options. The file is either an array of the rule identifiers to run, or an object that turns default rules off and sets options such as a limit or a severity. Unknown identifiers and unknown options are reported to standard error but are otherwise ignored so that linting can continue. A value of the wrong type or out of range stops the command with a validation error.

A severity from the configuration file is applied by wrapping the rule: the wrapper passes the rule's diagnostics on with the configured severity, so the rules themselves do not know about it.

## Resolving inputs

If no paths are provided, the current working directory is scanned. Otherwise, each path is resolved and any Markdown file (`.md`) is collected. Directories are traversed recursively to make sure nested documentation is linted alongside individual files that are explicitly specified; hidden files and directories such as `.build` or `.git` are skipped during traversal. A file reached through several arguments is linted once. A file that cannot be read as UTF-8 is skipped with a warning on standard error. A path that does not exist is reported as an error on standard error; the remaining paths are still linted, and the process then exits with status code `1`.

## Running the linter

All collected files are processed by a `Linter` from `MDLintCore`. The linter returns diagnostics and, when `--fix` is enabled, the fixed content. Fixed content is written back to disk whenever it differs from the original text, and the rewritten file is linted again so that only the remaining violations are reported.

## Excluding code and HTML

Rules check prose only. Before running the rules, the linter parses the file and replaces the following regions with placeholder characters:

- Fenced and indented code blocks
- Inline code spans
- HTML blocks and inline HTML, including comments

Text between matching backtick runs on one line is hidden as well when the parser does not treat it as a code span, which happens after an unclosed backtick run earlier in the paragraph.

Each hidden character becomes exactly one placeholder, so reported line and column numbers still match the file. The same masked text is handed to the automatic fixes, and the hidden regions are restored afterwards, which means `--fix` never rewrites code or HTML. Link destinations and front matter are not hidden.

Inline code and inline HTML stay part of the sentence around them, but their characters do not count toward the sentence-length limit: like URLs, they are often long without making the sentence harder to read.

## Turning rules off with comments

The linter also reads the HTML comments of the parsed file for directives: `<!-- mdlint-disable -->`, `<!-- mdlint-enable -->`, and `<!-- mdlint-disable-next-line -->`, each optionally followed by rule identifiers. From them it works out, for every line, which rules are turned off. See <doc:DisableComments> for the syntax.

The rules themselves do not know about the directives. Each rule checks the whole file, and the linter then discards the diagnostics reported on lines where that rule is off. Automatic fixes work the same way: a rule fixes the whole text, and the linter puts back the lines on which the rule is off. This needs the lines before and after the fix to correspond, so in a file that contains directives a fix that changes the number of lines is not applied.

## Reporting diagnostics

Diagnostics are sorted for stable output before being printed. Two output formats are supported:

- `text`: a human-readable listing that mirrors common command-line linters.
- `gha`: a format tailored for GitHub Actions so annotations appear directly in workflow logs.

When the `--strict` flag is supplied the process exits with status code `2` if any diagnostics were emitted, allowing continuous integration pipelines to fail the build on lint violations. A path that does not exist makes the process exit with status code `1`, with or without `--strict`.
