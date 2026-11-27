#!/bin/sh
# shellcheck disable=SC1010,SC2209  # state words as arguments
# Build a throwaway tmux server showing every state, for screenshots and tyre kicking.
#
#   sh docs/demo.sh            create it (server name: demo)
#   tmux -L demo attach        look at it; prefix + N / A / W / P work as usual
#   tmux -L demo kill-server   throw it away
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
AS="$ROOT/bin/agent-signal"
export TMUX_TMPDIR="${TMUX_TMPDIR:-/tmp}"
D() { tmux -L demo "$@"; }

D kill-server 2>/dev/null || true
D -f /dev/null new-session -d -s work -n api -x 200 -y 12 -c /tmp
D set -g base-index 1; D move-window -r
for w in web docs infra data; do D new-window -d -n "$w" -c /tmp; done

# A quiet status bar so the badges are the only colour that carries meaning:
# near-black band, mid-grey tabs, the current tab in bright bold white.
D set -g status-style 'bg=#1c1c1c,fg=#808080'
D set -g window-status-style 'fg=#808080,bg=default'
D set -g window-status-current-style 'fg=#e0e0e0,bold,bg=default'
D set -g status-justify centre
D set -g status-right-length 90
# The usage meter is a segment like any other: #{@agent_limits}, placed here
# between the CI status and the battery.
D set -g status-right "#{?client_prefix,#[reverse]<Prefix>#[noreverse], } #[fg=green]✓ CI main#[default]  #{?@agent_limits,#{@agent_limits}  ,}#[fg=green][86%%] ↯#[default]  Mon, Sep 07 - 10:42 am "
D set -g status-left "[work] "
D set -g @agent_signal_sound off
D set -g @agent_signal_limits on

# The plugin scripts exit early unless $TMUX is set, and use it to find the
# server, so fabricate the value tmux would export inside a pane of this one.
TMUX="$TMUX_TMPDIR/tmux-$(id -u)/demo,0,0"; export TMUX
sh "$ROOT/agent-signal.tmux"

pane() { D list-panes -t "$1" -F '#{pane_id}' | head -1; }
put() { # put <window> <name> <kind> <state>
  D set -p -t "$(pane "$1")" @agent_name "$2"
  TMUX_PANE=$(pane "$1") AGENT_KIND=$3 "$AS" set "$4"
}
put api   api/payments claude working
put web   web/checkout claude blocked
put docs  docs         claude done
put infra infra/tf     codex  ask
put data  data/etl     claude working

# Made-up allowances for the usage meter, as the agents would have reported
# them: Claude with 62% of its 5-hour window left and 3h24m to go (a little
# behind an even burn-down, not yet enough to colour), Codex with 40% left
# and 2h20m to go. The weekly window has more left, so it is not shown.
now=$(date +%s)
D set -g @agent_limit_claude_at "$now"
D set -g @agent_limit_claude_5h_used 38; D set -g @agent_limit_claude_5h_reset $((now + 12240))
D set -g @agent_limit_claude_7d_used 30; D set -g @agent_limit_claude_7d_reset $((now + 345600))
D set -g @agent_limit_codex_at "$now"
D set -g @agent_limit_codex_5h_used 60;  D set -g @agent_limit_codex_5h_reset $((now + 8400))
"$AS" limits

D send-keys -t work:1 'clear; echo "api/payments  ·  claude --name api/payments"; echo; echo "> Adding idempotency keys to POST /charges ..."; echo; echo "  ✻ Working (12s · 3 tool uses)"' C-m
D select-window -t work:1
echo "demo server ready: tmux -L demo attach"
