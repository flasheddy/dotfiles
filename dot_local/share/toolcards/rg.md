---
tool: rg
binary: /usr/bin/rg
authoritative: rg --help
---

# rg

## Verified gotchas

- **`rg` exits 1 when there are no matches.** That is normal, not an error — but
  under `set -e` it aborts the script, and inside `$( … )` it aborts command
  substitution. Guard with `|| true`, or use it directly as an `if` condition.
- **`-o -r '$1'` prints capture group 1.** Single-quote the `$1` so the shell does
  not expand it first. This is how the sha256 is read out of a
  `<!-- floor-contract: … -->` marker.
- **`-x -F -- "$str"` is an exact whole-line, fixed-string match.** The gate uses
  it to resolve a cited heading without a prefix false positive —
  `## Normative Tradecraft Standard` must *not* match
  `## Normative Tradecraft Standard (Canonical)`.
- **`-U` enables multiline matching**; without it a pattern never crosses a
  newline, even when the text clearly appears to.
- **`--no-filename`** suppresses the path prefix when scanning a single file, so
  `-o` output is just the captured text.
