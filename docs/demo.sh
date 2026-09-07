#!/bin/sh
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

# A plain status bar so the badges are the only colour that carries meaning.
D set -g status-style 'bg=#666666,fg=#aaaaaa'
D set -g window-status-style 'fg=#001a4d,bg=default'
D set -g window-status-current-style 'fg=white,bold,bg=red'
D set -g status-justify centre
D set -g status-left-length 50
D set -g status-right-length 90
D set -g status-right "#{?client_prefix,#[reverse]<Prefix>#[noreverse], } #[fg=green]✓ CI main#[default]  [86%%] ⚡  Mon, Sep 07 - 10:42 "
D set -g status-left "#{?@agent_needs,#[fg=black#,bg=colour208#,bold] #{@agent_needs} need you #[default],#[fg=colour245] clear #[default]} #[fg=cyan]#{@agent_name}#[default]"
D set -g @agent_signal_sound off

export TMUX="$TMUX_TMPDIR/tmux-$(id -u)/demo,0,0"   # point the plugin at this server
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

D send-keys -t work:1 'clear; echo "api/payments  ·  claude --name api/payments"; echo; echo "> Adding idempotency keys to POST /charges ..."; echo; echo "  ✻ Working (12s · 3 tool uses)"' C-m
D select-window -t work:1
echo "demo server ready: tmux -L demo attach"
