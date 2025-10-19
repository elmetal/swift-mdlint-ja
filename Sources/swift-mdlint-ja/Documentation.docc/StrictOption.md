# Enforcing zero-tolerance runs with ``swift-mdlint-ja``

See how the `--strict` flag influences exit codes for automation scenarios.

## Overview

By default `mdlint-ja` exits with code `0` even when it reports violations. Enabling `--strict` instructs the tool to exit with status `2` whenever any diagnostics are emitted.

## Usage

```bash
mdlint-ja --strict Docs
mdlint-ja --strict --fix README.md
```

- Combine `--strict` with `--fix` to apply automatic corrections while still failing the run when issues remain.
- Continuous integration pipelines can treat exit code `2` as a hard failure to block merges that do not meet style expectations.

## Behavior summary

- Exit code `0`: No diagnostics were produced.
- Exit code `2`: Diagnostics were produced and `--strict` was supplied.
- Other codes: Reserved for unexpected runtime errors.
