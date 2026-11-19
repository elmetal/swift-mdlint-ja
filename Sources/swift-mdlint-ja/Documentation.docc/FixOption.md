# Fixing violations with ``swift-mdlint-ja``

Understand how the `--fix` (`-f`) flag applies automatic corrections to Markdown files.

## Overview

When you supply the `--fix` flag, the linter corrects the violations whose rules provide a fix. Each modified file is written back to disk only when the changes alter the original contents. After a file is rewritten, the linter reports only the violations that remain in it, with locations that match the rewritten file.

The linter applies the fixes that do not overlap, checks the result again, and repeats until nothing is left to fix. One run is therefore enough even when a fix uncovers another violation, and running `--fix` a second time changes nothing.

## Usage

```bash
mdlint-ja --fix Articles
mdlint-ja -f README.md
```

- The option is disabled by default; omit the flag when you want to perform a dry run.
- If a file cannot be read as UTF-8, it is skipped with a warning on standard error.
- If the fixed content cannot be written back, a warning is printed on standard error and the diagnostics for the unmodified file are reported.
- Code blocks, inline code, and raw HTML are never modified.
- Lines on which a rule is turned off by a comment are not modified by that rule. See <doc:DisableComments>.

## Workflow tips

- Pair `--fix` with `--strict` to automatically correct what you can and fail the build when issues remain.
- Consider running the command in a clean working tree so you can review every change produced by the tool.
