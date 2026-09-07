#!/bin/sh
# With PATH empty the scripts must fall back to a known install path or exit 0,
# never die on an unbound variable.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

out=$(PATH=/nonexistent /bin/sh "$ROOT/agent-signal.tmux" 2>&1); rc=$?
is "entry file says nothing about an unbound variable" "$(printf '%s\n' "$out" | grep -c unbound)" 0
is "entry file survives an empty PATH"                 "$rc" 0
is "switcher survives an empty PATH"    "$(PATH=/nonexistent /bin/sh "$ROOT/scripts/switcher.sh" </dev/null 2>&1 | grep -c unbound)" 0

finish
