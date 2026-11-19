# Turning rules off inside a file

Use HTML comments to silence rules for part of a Markdown file.

## Overview

A configuration file chooses the rules for a whole run. To make an exception for a few lines, such as a quotation that must keep its original punctuation, write a comment in the file itself. The comments are ordinary HTML comments, so they do not appear in the rendered document.

## Turning rules off for a range of lines

`<!-- mdlint-disable -->` turns every rule off, and `<!-- mdlint-enable -->` turns every rule back on. Without an `mdlint-enable` comment, the rules stay off until the end of the file.

```markdown
<!-- mdlint-disable -->

この段落は検査されません.

<!-- mdlint-enable -->
```

## Turning rules off for one line

`<!-- mdlint-disable-next-line -->` turns every rule off for the line that follows the comment.

```markdown
<!-- mdlint-disable-next-line -->
この行は検査されません.
この行は検査されます。
```

## Choosing the rules

Each of the three comments accepts rule identifiers after the keyword, separated by spaces or commas. The comment then applies to those rules only. The identifiers are the ones shown in the `text` output and used in configuration files.

```markdown
<!-- mdlint-disable ja.comma.max-three ja.period.prefer-fullwidth -->

...

<!-- mdlint-enable ja.comma.max-three -->
```

After the second comment in this example, `ja.comma.max-three` is on again and `ja.period.prefer-fullwidth` is still off. `<!-- mdlint-enable -->` without identifiers turns every rule back on.

An identifier that belongs to no rule has no effect and is not reported.

## Details

- A comment decides the state of the whole line on which it ends, so `<!-- mdlint-disable -->` in the middle of a line also covers the text before it on that line. When several comments end on one line, the last one wins.
- `mdlint-disable-next-line` covers one line of the file, not one sentence or paragraph.
- A diagnostic is suppressed when the line it is reported on is turned off for its rule. A rule that looks at a whole sentence reports one position, usually where the limit is exceeded.
- `--fix` leaves the lines that are turned off for a rule exactly as they are, and still applies that rule's fixes to the other lines.
- A comment inside a code block or a code span is not read.
- The keywords are lowercase.
