# Loading rule configurations in ``swift-mdlint-ja``

Configure the linter by pointing `--config` to a JSON file that lists rule identifiers.

## Overview

The `--config` option lets you control which lint rules run without recompiling the tool. Provide a path to a JSON file containing an array of rule identifiers; unknown identifiers are ignored after emitting a warning to standard error.

## Usage

```bash
mdlint-ja --config .mdlint.json Docs
```

Example configuration file:

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

- Paths can be absolute or relative to the current working directory.
- Omit the option to run with the tool's default rule set.
- When the referenced file is missing, the command fails with a validation error describing the missing path.
