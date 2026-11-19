# Loading rule configurations in ``swift-mdlint-ja``

Configure the linter by pointing `--config` to a JSON file that chooses the rules and sets their options.

## Overview

The `--config` option lets you control which lint rules run, how strict they are, and how their violations are reported, without recompiling the tool. The file takes one of two forms: an object that adjusts the default rule set, or an array that lists the rules to run.

```bash
mdlint-ja --config .mdlint.json Docs
```

- Paths can be absolute or relative to the current working directory.
- Omit the option to run every rule with its default settings.
- When the referenced file is missing, the command fails with a validation error describing the missing path.

## Adjusting the default rules

Write an object with a `rules` key. Each entry names a rule and gives one of the following values:

- `false` turns the rule off.
- `true` runs the rule with its default settings.
- An object runs the rule with the options in it.

Rules that the file does not mention keep running with their default settings.

```json
{
  "rules": {
    "ja.sentence.max-length": { "max": 120 },
    "ja.comma.max-count": { "max": 4, "severity": "error" },
    "ja.kana.no-halfwidth": false
  }
}
```

### Options

| Option | Rules | Value | Default |
| --- | --- | --- | --- |
| `severity` | Every rule | `"info"`, `"warning"`, or `"error"` | `"warning"` |
| `max` | `ja.comma.max-count` | The number of commas a sentence may contain, `1` or more | `3` |
| `max` | `ja.sentence.max-length` | The number of characters a sentence may contain, `1` or more | `100` |
| `style` | `ja.style.no-mix-dearu-desumasu` | `"auto"`, `"desumasu"`, or `"dearu"` | `"auto"` |

The `--politeness-style` option takes precedence over `style` when both are given.

### Severity

The severity changes how a violation is labeled: `[INFO]`, `[WARNING]`, or `[ERROR]` in the `text` format, and `notice`, `warning`, or `error` annotations in the `gha` format. It does not change the exit code. With `--strict`, a violation of any severity makes the command exit with code `2`.

## Listing the rules to run

Write an array of rule identifiers. Only the listed rules run, each with its default settings.

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

## Renamed rules

Two rules were renamed when their limits became adjustable. Both forms of the configuration file still accept the former names, and diagnostics show the current ones. Comments that turn rules off (see <doc:DisableComments>) take the current names only.

| Former name | Current name |
| --- | --- |
| `ja.comma.max-three` | `ja.comma.max-count` |
| `ja.sentence.max-one-hundred-characters` | `ja.sentence.max-length` |

## Mistakes in the file

- A rule identifier that does not exist is reported as a warning on standard error and ignored.
- An option that a rule does not accept, such as `max` for a rule without a limit, is reported as a warning on standard error and ignored.
- Anything else stops the command with exit code `64` and a message that names the problem: a file that is not JSON, a key other than `rules` at the top level, a value of the wrong type, a `max` below `1`, an unknown `severity` or `style`, or a rule that appears under both its former and its current name.
