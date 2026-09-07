#!/bin/sh
# Shared fixture and assertions for the per-feature tests in this directory.
# No daemon, no mocks: the real scripts drive a real, isolated tmux server.
#
#   sh test/t-hooks.sh          run one feature's tests
#   sh test/run.sh              run all of them
#   KEEP=1 sh test/t-hooks.sh   leave that test's server running for inspection
#
# No client is ever attached to that server, so no window is ever "visible" to
# the plugin. The auto-acknowledge branch in bin/agent-signal -- finishing in a
# window you are already looking at clears the flag instead of raising it --
# needs an attached client and is therefore out of scope for this suite: the
# tests assert the "nobody is looking" side of it, where done always shows.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
AS="$ROOT/bin/agent-signal"
# One server per test file, named after the file and tagged with a hash of this
# checkout plus this pid, so two worktrees -- or two concurrent runs of the
# same file -- can never land on the same socket.
SOCK="agent-signal-test-$(basename "$0" .sh | sed 's/^t-//')-$(printf '%s' "$ROOT" | cksum | cut -d' ' -f1)-$$"
SOCK_PATH="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCK"

T() { tmux -L "$SOCK" "$@"; }

# --- assertions ------------------------------------------------------------
pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n       got: [%s]  want: [%s]\n' "$1" "$2" "$3"; }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }
strip() { sed 's/#\[[^]]*\]//g'; }
# Async hooks (run-shell -b) finish on their own schedule: poll for a window state.
waitfor() { i=0; while [ "$(wst "$1")" != "$2" ] && [ $i -lt 100 ]; do sleep 0.05; i=$((i + 1)); done; }

# --- probes ----------------------------------------------------------------
hook() { # hook <pane> <event> [json]
  printf '%s' "${3:-{\}}" | TMUX_PANE=$1 "$AS" hook "$2"
}
wst()  { T show-option -wqv -t "$1" @agent_state; }
wicon(){ T show-option -wqv -t "$1" @agent_icon; }
wstyle(){ T show-option -wqv -t "$1" window-status-style; }
whold(){ T show-option -wqv -t "$1" @agent_hold; }
pst()  { T display -p -t "$1" '#{@agent_pane_state}'; }
gneeds(){ T show-option -gqv @agent_needs; }
gsum() { T show-option -gqv @agent_summary | strip; }

# --- actions ---------------------------------------------------------------
# A whole turn in one pane: a prompt goes in, the agent finishes.
drive_done() { hook "$1" UserPromptSubmit; hook "$1" Stop; }
# Single-byte glyphs, so a column count is a column count and not a byte count.
ascii() { # ascii on|off
  if [ "$1" = on ]; then T set-option -g @agent_signal_ascii on
  else T set-option -gu @agent_signal_ascii; fi
}
# How many files or directories matching <pattern> the scripts left in the
# private TMPDIR of this test file.
leftovers() { # leftovers <pattern>
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name "$1" | wc -l | tr -d ' '
}

# --- fixture ---------------------------------------------------------------
_cleaned=0; _rc=0
# Kill this file's server and remove its private TMPDIR, once, however the
# file ends: a normal finish, a die under `set -u`, or a Ctrl-C.
cleanup() {
  [ "$_cleaned" = 0 ] || return 0
  _cleaned=1
  [ "${KEEP:-}" != 1 ] || return 0
  T kill-server 2>/dev/null
  # tmux leaves the socket file behind, and this name is used once ever.
  rm -f "$SOCK_PATH"
  case ${TMPDIR:-} in */agent-signal-test.*) rm -rf "$TMPDIR" ;; esac
  return 0
}

# The environment only, for the tests that need no tmux server at all: a
# private TMPDIR (the plugin's lock directories and temp files land there, so a
# live server's hooks on the same machine cannot bleed into the "nothing left
# behind" checks, and test files can run in parallel) and a $TMUX pointing at
# this file's socket, started or not.
setup_env() {
  trap 'cleanup; exit 130' INT
  trap 'cleanup; exit 143' TERM
  trap 'cleanup; exit 129' HUP
  trap '_rc=$?; cleanup; exit $_rc' EXIT
  TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/agent-signal-test.XXXXXX") && export TMPDIR
  # The scripts talk to whatever server $TMUX points at, so point it at ours.
  TMUX="$SOCK_PATH,0,0"; export TMUX
}

# A fresh server with three windows: shell (active), api (one pane) and
# web (two panes). Every test file that needs a server starts from this state.
# shellcheck disable=SC2034  # the window and pane ids are read by the sourcing test file
setup() {
  setup_env
  T kill-server 2>/dev/null
  T -f /dev/null new-session -d -s main -n shell -x 120 -y 30
  T set-option -g @agent_signal_sound off          # no afplay in CI
  T set-option -g @agent_signal_tab_colour on
  sh "$ROOT/agent-signal.tmux"

  W_API=$(T new-window -d -n api -P -F '#{window_id}')
  W_WEB=$(T new-window -d -n web -P -F '#{window_id}')
  P_API=$(T list-panes -t "$W_API" -F '#{pane_id}')
  P_WEB=$(T list-panes -t "$W_WEB" -F '#{pane_id}')
  P_WEB2=$(T split-window -d -t "$W_WEB" -P -F '#{pane_id}')
}

finish() {
  cleanup
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
