# ``MDLintConfig``

## Overview

`MDLintConfig` resolves which lint rules to run and with which settings. It reads a JSON configuration file, reports the rule identifiers and options it does not recognize, and returns the matching rules from the `MDLintRules` module. Without a configuration file, every default rule is enabled.

The file is either an array of the rule identifiers to run, or an object whose `rules` entry turns default rules off and sets their options: `severity` for every rule, `max` for the comma and sentence-length limits, and `style` for the politeness-style rule.

## Topics

### Loading Configuration
- ``RuleConfigurationLoader``

