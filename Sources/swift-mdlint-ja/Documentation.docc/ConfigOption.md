# Loading rule configurations in ``swift-mdlint-ja``

Configure the linter with a JSON file that chooses the rules, sets their options, and excludes files.

## Overview

A configuration file lets you control which lint rules run, how strict they are, how their violations are reported, and which files are left out, without recompiling the tool. The file takes one of two forms: an object that adjusts the default rule set and excludes files, or an array that lists the rules to run.

## Finding the configuration file

Name the file `.mdlint.json` and put it at the top of your project. When `--config` is not given, the command looks for `.mdlint.json` in the current working directory, then in each parent directory up to the root of the file system, and uses the first one it finds. A project is therefore linted the same way from any of its directories.

```bash
cd Docs/Guide
mdlint-ja            # uses ../../.mdlint.json when that is the nearest one
```

- Only the nearest file is used. Files further up are not merged into it.
- The search starts from the current working directory, not from the files being linted.
- When no file is found, every rule runs with its default settings and no file is excluded.

The `--config` option names a file instead, and no search takes place:

```bash
mdlint-ja --config strict.json Docs
```

- The path can be absolute or relative to the current working directory.
- When the referenced file is missing, the command fails with a validation error describing the missing path. It does not fall back to `.mdlint.json`.

The `--no-config` flag turns the search off, so that every rule runs with its default settings and no file is excluded. It cannot be combined with `--config`.

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

## Excluding files

Add an `exclude` key to the object, next to `rules`, with the patterns of the files to leave out:

```json
{
  "exclude": ["vendor/**", "CHANGELOG.md", "**/draft-*.md"],
  "rules": {
    "ja.kana.no-halfwidth": false
  }
}
```

A file that matches a pattern is neither checked nor rewritten by `--fix`.

### Pattern syntax

A pattern is a path whose components are separated by `/`.

| Pattern | Matches |
| --- | --- |
| `*` | Any number of characters within one path component. `*.md` matches `a.md` but not `docs/a.md`. |
| `?` | Exactly one character within one path component. `v?.md` matches `v1.md` but not `v10.md`. |
| `**` | Any number of path components, including none, when it is a whole component. `**/notes.md` matches `notes.md` and `docs/2024/notes.md`. |

- Every other character matches itself, and case matters. Character classes (`[a-z]`), alternatives (`{a,b}`), negation (`!`), and escaping with `\` are not supported.
- A pattern is relative to the directory of the configuration file, not to the current working directory. This also holds for a file named with `--config`.
- A pattern is matched from the start of the path. `CHANGELOG.md` matches only the file next to the configuration file; write `**/CHANGELOG.md` to match the name at any depth.
- A pattern that matches a directory excludes everything in it, so `vendor`, `vendor/`, and `vendor/**` all exclude the whole directory.
- A pattern cannot be empty, start with `/`, or contain a `..` component. Files outside the directory of the configuration file are never excluded.
- Paths are compared as they are written, without resolving symbolic links.

### Files named on the command line

The patterns also apply to files and directories that are named as arguments. `mdlint-ja CHANGELOG.md` lints nothing when `CHANGELOG.md` is excluded, and prints no warning. This keeps the exclusion in effect for tools that pass file names to the command, such as pre-commit hooks. Use `--no-config` or another `--config` file to lint such a file.

An argument that does not exist is still reported as an error, whether or not it matches a pattern.

## Listing the rules to run

Write an array of rule identifiers. Only the listed rules run, each with its default settings. This form cannot exclude files.

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
- Anything else stops the command with exit code `64` and a message that names the file and the problem: a file that is not JSON, a key other than `rules` and `exclude` at the top level, a value of the wrong type, a `max` below `1`, an unknown `severity` or `style`, an `exclude` pattern that is empty, absolute, or contains `..`, or a rule that appears under both its former and its current name. This applies to a `.mdlint.json` that was found by the search as well.
