# ``MDLintConfig``

## Overview

`MDLintConfig` resolves which lint rules to run, with which settings, and on which files. It finds the nearest `.mdlint.json` above a directory, reads a JSON configuration file, reports the rule identifiers and options it does not recognize, and returns the matching rules from the `MDLintRules` module together with the patterns of the excluded files. Without a configuration file, every default rule is enabled and no file is excluded.

The file is either an array of the rule identifiers to run, or an object. The `rules` entry of the object turns default rules off and sets their options: `severity` for every rule, `max` for the comma and sentence-length limits, and `style` for the politeness-style rule. Its `exclude` entry lists patterns, relative to the directory of the file, of the files to leave out.

## Topics

### Loading Configuration
- ``RuleConfigurationLoader``
- ``LintConfiguration``

### Excluding Files
- ``PathPattern``

