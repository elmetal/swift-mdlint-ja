# Fixing violations with ``swift-mdlint-ja``

Understand how the `--fix` (`-f`) flag applies automatic corrections to Markdown files.

## Overview

When you supply the `--fix` flag, the linter attempts to correct any violations whose rules provide fix-its. Each modified file is written back to disk only when the suggested changes alter the original contents.

## Usage

```bash
mdlint-ja --fix Articles
mdlint-ja -f README.md
```

- The option is disabled by default; omit the flag when you want to perform a dry run.
- If a file cannot be read or written, the linter skips the automatic fix but still reports diagnostics.

## Workflow tips

- Pair `--fix` with `--strict` to automatically correct what you can and fail the build when issues remain.
- Consider running the command in a clean working tree so you can review every change produced by the tool.
