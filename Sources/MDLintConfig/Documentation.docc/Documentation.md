# ``MDLintConfig``

## Overview

`MDLintConfig` resolves which lint rules to run. It reads a JSON configuration file that lists rule identifiers, reports identifiers it does not recognize, and returns the matching rules from the `MDLintRules` module. Without a configuration file, every default rule is enabled.

## Topics

### Loading Configuration
- ``RuleConfigurationLoader``

