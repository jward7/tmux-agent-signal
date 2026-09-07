#!/bin/sh
# tmux-agent-signal entry point (sourced by tpm, or via run-shell from tmux.conf).
# Appends the agent badge to the window-status formats, installs key bindings,
# and wires the "viewed -> idle" hooks. Idempotent: safe to source repeatedly.
set -u
CURRENT_DIR=$(cd "$(dirname "$0")" && pwd)
AS="$CURRENT_DIR/bin/agent-signal"
SW="$CURRENT_DIR/scripts/switcher.sh"
chmod +x "$AS" "$SW" 2>/dev/null

if command -v tmux >/dev/null 2>&1; then TMUX_BIN=tmux; else
  for c in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux /opt/homebrew/Cellar/tmux/*/bin/tmux /usr/local/Cellar/tmux/*/bin/tmux; do
    [ -x "$c" ] && TMUX_BIN=$c && break
  done
fi
t() { "$TMUX_BIN" "$@"; }
opt() { v=$(t show-option -gqv "$1"); [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$2"; }

# --- status bar badge -------------------------------------------------------
BADGE='#{?#{@agent_icon}, #[fg=#{@agent_fg}#,bold]#{@agent_icon}#[default],}'
for o in window-status-format window-status-current-format; do
  cur=$(t show-option -gqv "$o")
  case $cur in *@agent_icon*) ;; *) t set-option -g "$o" "${cur}${BADGE}" ;; esac
done

# --- key bindings (prefix + key; set an option to "" to skip a binding) ------
bind() { k=$(opt "$1" "$2"); [ -n "$k" ] && t bind-key "$k" "$3"; }
bind @agent_signal_key_next     N "run-shell -b '$AS next'"
bind @agent_signal_key_switcher A "display-popup -E -w 70% -h 70% '$SW'"
bind @agent_signal_key_wait     W "run-shell -b '$AS hold wait'"
bind @agent_signal_key_park     P "run-shell -b '$AS hold park'"

# --- viewed -> idle ----------------------------------------------------------
# Use a high array index so we never clobber hooks set elsewhere.
for h in after-select-window client-session-changed client-attached; do
  t set-hook -g "${h}[91]" "run-shell -b '$AS seen'"
done

# One-shot sync so windows that already have Claude sessions get their names.
t run-shell -b "$AS sync"
