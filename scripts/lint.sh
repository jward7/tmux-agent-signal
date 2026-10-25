#!/bin/sh
# Static checks, the same ones CI runs: sh scripts/lint.sh
#   ShellCheck in POSIX sh mode (correctness)
#   checkbashisms: constructs that work in bash-as-sh (macOS) but not dash (Ubuntu)
#   function size: no function in bin/agent-signal over MAX_FN lines, so the
#                  single-file layout stays readable without splitting it
set -u
cd "$(dirname "$0")/.." || exit 1
FILES="bin/agent-signal scripts/switcher.sh scripts/lint.sh agent-signal.tmux docs/demo.sh docs/record-demo.sh test/run.sh test/lib.sh"
for f in test/t-*.sh; do FILES="$FILES $f"; done
MAX_FN=${MAX_FN:-60}
rc=0

# shellcheck disable=SC2086  # FILES is a list, split on purpose
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -s sh $FILES && echo "shellcheck: ok" || rc=1
else echo "shellcheck: not installed" >&2; rc=1; fi

# shellcheck disable=SC2086
if command -v checkbashisms >/dev/null 2>&1; then
  out=$(checkbashisms -f $FILES 2>&1); if [ -z "$out" ]; then echo "checkbashisms: ok"; else printf '%s\n' "$out"; rc=1; fi
else echo "checkbashisms: not installed" >&2; rc=1; fi

# Function bodies run from "name() {" at column 0 to the next "}" at column 0.
long=$(awk -v max="$MAX_FN" '
  /^[a-z_]+\(\) *\{/ { name = $1; start = NR }
  /^\}/ && name != "" { n = NR - start + 1; if (n > max) printf "  %s is %d lines (max %d)\n", name, n, max; name = "" }
' bin/agent-signal)
if [ -z "$long" ]; then echo "function size: ok (max $MAX_FN lines)"; else echo "function size: too long"; printf '%s\n' "$long"; rc=1; fi

exit $rc
