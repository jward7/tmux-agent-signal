#!/bin/sh
# @agent_signal_notify: a desktop notification when a window starts needing
# you, through the first notifier on PATH (terminal-notifier, else osascript,
# else notify-send). The notifiers are PATH shims that log their argv.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

LOG="$TMPDIR/notify.log"
# A shim: one argv word per line, appended to the log.
shim() { # shim <dir> <name>
  mkdir -p "$1"
  printf '%s\n' '#!/bin/sh' "for a; do printf '%s\\n' \"\$a\"; done >> '$LOG'" > "$1/$2"
  chmod +x "$1/$2"
}
# What the hook needs and nothing else: no notifier of any kind.
TOOLS="$TMPDIR/tools"; mkdir -p "$TOOLS"
for b in sh cat tmux awk sed grep tr head cut sort mkdir rmdir sleep id dirname date; do ln -s "$(command -v "$b")" "$TOOLS/$b"; done
hookp() { printf '{}' | PATH=$1 TMUX_PANE=$2 "$AS" hook "$3"; } # hookp <PATH> <pane> <event>
# The notifier runs in the background: poll until the log has <n> lines.
waitlog() { i=0; while [ "$(wc -l < "$LOG" 2>/dev/null | tr -d ' ')" -lt "$1" ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i + 1)); done; }

T set-option -g @agent_signal_notify on
: > "$LOG"
IDX=$(T display -p -t "$W_API" '#{window_index}')

shim "$TMPDIR/tn" terminal-notifier
hookp "$TMPDIR/tn:$PATH" "$P_API" PermissionRequest; waitlog 4
is "terminal-notifier is called with title and session:index name" "$(cat "$LOG")" "-title
Agent blocked
-message
main:$IDX api"
hookp "$TMPDIR/tn:$PATH" "$P_API" PermissionRequest; sleep 0.3
is "a repeat of the same state does not notify again" "$(wc -l < "$LOG" | tr -d ' ')" 4

: > "$LOG"
shim "$TMPDIR/osa" osascript
hookp "$TMPDIR/osa:$TOOLS" "$P_API" UserPromptSubmit
hookp "$TMPDIR/osa:$TOOLS" "$P_API" PermissionRequest; waitlog 2
is "without terminal-notifier, osascript is called" "$(cat "$LOG")" "-e
display notification \"main:$IDX api\" with title \"Agent blocked\""

: > "$LOG"
hookp "$TOOLS" "$P_API" UserPromptSubmit
hookp "$TOOLS" "$P_API" PermissionRequest; rc=$?
is "with no notifier on PATH the hook still exits 0" "$rc" 0
is "with no notifier on PATH the state is still set" "$(wst "$W_API")" blocked

T set-option -g @agent_signal_notify off
hookp "$TMPDIR/tn:$PATH" "$P_API" Stop; sleep 0.3
is "notify off: nothing is called" "$(cat "$LOG")" ""

finish
