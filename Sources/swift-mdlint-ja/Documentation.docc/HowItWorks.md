# How ``swift-mdlint-ja`` Works

Learn how the command-line interface orchestrates rule loading, lint execution, and output formatting.

## Command-line entry point

The executable is defined by the `MDLintCommand` type, which uses `ArgumentParser` to expose the `mdlint-ja` command. The tool accepts Markdown file paths or directories to lint and offers options to apply automatic fixes (`--fix`), select a diagnostic format (`--format text|gha`), enable strict exit codes (`--strict`), point to a JSON configuration file (`--config`) or turn the search for one off (`--no-config`), and choose the preferred politeness style (`--politeness-style auto|desumasu|dearu`).

## Loading lint rules

When the command starts it creates a `RuleConfigurationLoader`. Unless `--config` names a configuration file, the loader looks for `.mdlint.json` in the current working directory and then in each parent directory, and takes the first one it finds; `--no-config` skips the search. The loader reads the configuration file, if there is one, to determine which rules from `MDLintRules` should be active and with which options, and which files are excluded. The file is either an array of the rule identifiers to run, or an object that turns default rules off and sets options such as a limit, a severity, or the terms whose spelling to keep consistent. Unknown identifiers and unknown options are reported to standard error but are otherwise ignored so that linting can continue. A value of the wrong type or out of range stops the command with a validation error, and so do registered terms that contradict each other.

A severity from the configuration file is applied by wrapping the rule: the wrapper passes the rule's diagnostics on with the configured severity, so the rules themselves do not know about it.

## Resolving inputs

If no paths are provided, the current working directory is scanned. Otherwise, each path is resolved and any Markdown file (`.md`) is collected. Directories are traversed recursively to make sure nested documentation is linted alongside individual files that are explicitly specified; hidden files and directories such as `.build` or `.git` are skipped during traversal. Files and directories that match an `exclude` pattern of the configuration file are left out, both during traversal, where an excluded directory is not entered, and when they are named as arguments. The patterns are matched against the path relative to the directory of the configuration file. A file reached through several arguments is linted once. A file that cannot be read as UTF-8 is skipped with a warning on standard error. A path that does not exist is reported as an error on standard error; the remaining paths are still linted, and the process then exits with status code `1`.

## Running the linter

All collected files are processed by a `Linter` from `MDLintCore`. The linter returns diagnostics and, when `--fix` is enabled, the fixed content. Fixed content is written back to disk whenever it differs from the original text, and the rewritten file is linted again so that only the remaining violations are reported.

## Applying fixes

A rule that can fix a violation attaches a fix-it to its diagnostic: the range of text to replace, given as lines and columns like the diagnostic itself, and the replacement. The rule finds the violation and describes its fix in the same scan, so what is reported is what gets fixed.

With `--fix`, the linter collects the fix-its of the diagnostics it found and applies those that do not overlap. Of two that overlap, the one that starts earlier is applied, or the one of the earlier rule when both start at the same place. It then checks the result again and repeats, because a fix can uncover another violation, and because the fix-it that had to wait may still apply. For example, a heading that ends in a half-width period first has the period replaced by "。" and then, in the next pass, removed. The linter stops when nothing is left to fix, or after ten passes.

## Excluding code and HTML

Rules check prose only. Before running the rules, the linter parses the file and replaces the following regions with placeholder characters:

- Fenced and indented code blocks
- Inline code spans
- HTML blocks and inline HTML, including comments

Text between matching backtick runs on one line is hidden as well when the parser does not treat it as a code span, which happens after an unclosed backtick run earlier in the paragraph.

Each hidden character becomes exactly one placeholder, so reported line and column numbers still match the file. Fix-its refer to the same masked text, and the linter skips a fix-it whose range overlaps a hidden region or would insert text inside one. The hidden regions are restored after the fix-its have been applied, which means `--fix` never rewrites code or HTML. Link destinations and front matter are not hidden.

Inline code and inline HTML stay part of the sentence around them, but their characters do not count toward the sentence-length limit: like URLs, they are often long without making the sentence harder to read.

## Turning rules off with comments

The linter also reads the HTML comments of the parsed file for directives: `<!-- mdlint-disable -->`, `<!-- mdlint-enable -->`, and `<!-- mdlint-disable-next-line -->`, each optionally followed by rule identifiers. From them it works out, for every line, which rules are turned off. See <doc:DisableComments> for the syntax.

The rules themselves do not know about the directives. Each rule checks the whole file, and the linter then discards the diagnostics reported on lines where that rule is off. A discarded diagnostic takes its fix-it with it, so `--fix` leaves those violations alone as well.

## Reporting diagnostics

Diagnostics are sorted for stable output before being printed. Two output formats are supported:

- `text`: a human-readable listing that mirrors common command-line linters.
- `gha`: a format tailored for GitHub Actions so annotations appear directly in workflow logs.

When the `--strict` flag is supplied the process exits with status code `2` if any diagnostics were emitted, allowing continuous integration pipelines to fail the build on lint violations. A path that does not exist makes the process exit with status code `1`, with or without `--strict`.
