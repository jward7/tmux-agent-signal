#!/bin/sh
# With PATH empty the scripts must fall back to a known install path or exit 0,
# never die on an unbound variable.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

out=$(PATH=/nonexistent /bin/sh "$ROOT/agent-signal.tmux" 2>&1); rc=$?
is "entry file says nothing about an unbound variable" "$(printf '%s\n' "$out" | grep -c unbound)" 0
is "entry file survives an empty PATH"                 "$rc" 0
is "switcher survives an empty PATH"    "$(PATH=/nonexistent /bin/sh "$ROOT/scripts/switcher.sh" </dev/null 2>&1 | grep -c unbound)" 0

# The status line entry has the user's previous command to run whatever has
# happened to tmux: found only at a fallback path, or not found at all.
BARE=$(mktemp -d); for b in sh cat dirname; do ln -s "$(command -v "$b")" "$BARE/$b"; done
out=$(printf 'payload\n' | PATH=$BARE "$AS" statusline 'cat' 2>&1); rc=$?
is "statusline with no tmux on PATH still runs the previous command" "$rc:$out" "0:payload"
# Every machine these tests run on has tmux at one of the fallback paths, so
# the not-found branch is reached with a copy of the script whose list is emptied.
mkdir -p "$TMPDIR/copy/bin"; COPY="$TMPDIR/copy/bin/agent-signal"
sed 's|^  for c in /opt/homebrew/bin/tmux .*; do$|  for c in /nonexistent/tmux; do|' "$AS" > "$COPY"; chmod +x "$COPY"
is "the copy has no fallback path left"             "$(grep -c 'for c in /nonexistent/tmux; do' "$COPY")" 1
out=$(printf 'payload\n' | PATH=$BARE "$COPY" statusline 'cat; exit 4' 2>&1); rc=$?
is "statusline with tmux nowhere at all still runs it, exit status and all" "$rc:$out" "4:payload"
out=$(PATH=$BARE "$COPY" set blocked 2>&1); rc=$?
is "every other command with tmux nowhere exits 0 and says nothing" "$rc:$out" "0:"
rm -rf "$BARE"

finish
