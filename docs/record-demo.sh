#!/bin/sh
# shellcheck disable=SC2016,SC1010  # literal $ in the PS1 we hand to sh; "done" is a state word
# Record docs/demo.gif: the demo server from docs/demo.sh, with agents changing
# state while you watch. Re-run this whenever badges, colours or the status
# line change so the README picture matches the code.
#
# Needs on PATH:
#   asciinema 3.x   https://github.com/asciinema/asciinema/releases  (prebuilt binaries)
#   agg             https://github.com/asciinema/agg/releases        (cast -> gif)
# On a Mac where Homebrew has no bottles (older macOS), download the
# x86_64/aarch64-apple-darwin binaries from those release pages into
# ~/.local/bin, chmod +x them, and `xattr -d com.apple.quarantine` them.
# agg needs a font with ✳ ✓ … ⬢: Menlo plus Apple Symbols covers it on macOS;
# on Linux try --font-family "DejaVu Sans Mono,Noto Sans Symbols2".
#
#   sh docs/record-demo.sh       writes docs/demo.cast and docs/demo.gif
#
# Nothing from the recording user's environment is shown: panes are respawned
# with a plain /bin/sh and PS1='$ ', the cwd is /tmp, and every project name,
# session name and clock in the status line is made up by docs/demo.sh.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/docs/demo"
export TMUX_TMPDIR="${TMUX_TMPDIR:-/tmp}"
sh "$ROOT/docs/demo.sh" >/dev/null
D() { tmux -L demo "$@"; }
# As demo.sh does: fabricate the $TMUX a pane of this server would have, so
# agent-signal talks to the demo server and not your real one.
TMUX="$TMUX_TMPDIR/tmux-$(id -u)/demo,0,0"; export TMUX
AS="$ROOT/bin/agent-signal"

pane() { D list-panes -t "work:$1" -F '#{pane_id}' | head -1; }
set_state() { TMUX_PANE=$(pane "$1") AGENT_KIND=${3:-claude} "$AS" set "$2"; }
# Replace a pane's shell with a fresh sh that prints the given lines first, so
# the text appears without any typed command echoing on screen. The agent
# state lives in pane options, which respawn keeps.
show() { # show <window> <line>...
  w=$1; shift
  body=""; for l in "$@"; do body="$body$l
"; done
  D set-environment -g DEMO_TEXT "$body"   # new panes inherit the server environment
  D respawn-pane -k -t "work:$w" 'printf "%s" "$DEMO_TEXT"; unset DEMO_TEXT; exec env PS1="$ " ENV= /bin/sh'
}

for w in 1 2 3 4 5; do show "$w" ""; done
show 1 "api/payments  ·  claude --name api/payments" "" "> Adding idempotency keys to POST /charges ..." "" "  ✻ Working (12s · 3 tool uses)"
show 2 "web/checkout  ·  claude --name web/checkout" "" "  Allow Bash(git push origin checkout)?  (y/n)"
show 4 "infra/tf  ·  codex" "" "  ? Apply this plan to production, or staging first?"

(
  sleep 2.5; show 1 "api/payments" "" "  ✻ Working (14s · 4 tool uses)"
  sleep 1.5; set_state data done
  sleep 1.5; set_state api blocked;  show 1 "api/payments" "" "  Allow Bash(git push)?  (y/n)"
  sleep 2.0; set_state api working;  show 1 "api/payments" "" "  ✻ Working (2s · 1 tool use)"
  sleep 1.5; D select-window -t work:2               # prefix + N would land here: oldest blocked
  sleep 2.0; set_state web working;  show 2 "web/checkout" "" "  ✻ Working (1s)"
  sleep 1.5; D select-window -t work:4               # next: the question
  sleep 1.5; set_state infra working codex; show 4 "infra/tf" "" "  Applying to staging ..."
  sleep 1.5; D select-window -t work:3               # done clears itself when viewed
  sleep 1.5; D select-window -t work:1
  sleep 1.5; set_state api done
  sleep 2.5; D detach-client -s work
  sleep 0.5; D kill-server
) &
TMUX='' asciinema rec --overwrite --window-size 150x12 -c "tmux -L demo attach -t work" "$OUT.cast"
wait
# Drop the "[detached]" tail so the GIF ends on the status bar.
awk '/\[detached/ {exit} {print}' "$OUT.cast" > "$OUT.cast.tmp" && mv "$OUT.cast.tmp" "$OUT.cast"
agg --font-family "Menlo,Apple Symbols" --font-size 20 --theme asciinema --last-frame-duration 3 "$OUT.cast" "$OUT.gif"
ls -la "$OUT.gif"
