#!/bin/sh
# Hierarchical session > window > pane switcher with close and triage actions.
# Runs inside `tmux display-popup`. Needs fzf.
set -u
PLUGIN_DIR=$(cd "$(dirname "$0")/.." && pwd)
AS="$PLUGIN_DIR/bin/agent-signal"

command -v fzf >/dev/null 2>&1 || { echo "agent-signal switcher needs fzf (brew install fzf)"; sleep 2; exit 1; }

# Same resolution as bin/agent-signal (Homebrew unlinks tmux mid-upgrade).
if command -v tmux >/dev/null 2>&1; then TMUX_BIN=tmux; else
  for c in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux /opt/homebrew/Cellar/tmux/*/bin/tmux /usr/local/Cellar/tmux/*/bin/tmux; do
    [ -x "$c" ] && TMUX_BIN=$c && break
  done
fi

while :; do
  out=$("$AS" list | fzf --reverse --no-sort --delimiter='\t' --with-nth=3.. \
        --header='enter: go   ctrl-x: close   ctrl-w: wait   ctrl-p: park   esc: quit' \
        --expect=ctrl-x,ctrl-w,ctrl-p \
        --prompt='agents> ') || exit 0
  key=$(printf '%s\n' "$out" | sed -n 1p)
  line=$(printf '%s\n' "$out" | sed -n 2p)
  [ -n "$line" ] || exit 0
  kind=${line%%	*}; rest=${line#*	}; target=${rest%%	*}; label=${rest#*	}

  case $kind in
    S) sess=$target; win="" ;;
    W) win=$target; sess=$("$TMUX_BIN" display -p -t "$win" '#{session_name}') ;;
    P) win=$("$TMUX_BIN" display -p -t "$target" '#{window_id}'); sess=$("$TMUX_BIN" display -p -t "$target" '#{session_name}') ;;
  esac

  case $key in
    ctrl-x)
      printf 'Close %s? [y/N] ' "$label"; read -r yn < /dev/tty
      case $yn in y|Y)
        case $kind in
          S) "$TMUX_BIN" kill-session -t "$sess" ;;
          W) "$TMUX_BIN" kill-window -t "$win" ;;
          P) "$TMUX_BIN" kill-pane -t "$target" ;;
        esac ;;
      esac
      continue ;;
    ctrl-w|ctrl-p)
      [ -n "$win" ] || continue
      mode=wait; [ "$key" = ctrl-p ] && mode=park
      "$AS" hold "$mode" "$win"
      continue ;;
    *)
      "$TMUX_BIN" switch-client -t "$sess" 2>/dev/null
      [ -n "$win" ] && "$TMUX_BIN" select-window -t "$win"
      [ "$kind" = P ] && "$TMUX_BIN" select-pane -t "$target"
      exit 0 ;;
  esac
done
