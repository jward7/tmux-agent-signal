#!/bin/sh
# The status-right summary per agent kind and state: glyph by AGENT_KIND,
# colour by pane state, and the needs-you count as windows come and go.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup
unset AGENT_KIND
HOME=$TMPDIR; export HOME   # SessionStart syncs from ~/.claude/sessions: keep the real one out

rawsum() { T show-option -gqv @agent_summary; }
# Poll a command's output until it equals <want> (async hooks), at most ~10s.
waitcmd() { # waitcmd <want> <cmd...>
  w=$1; shift; i=0
  while [ "$("$@")" != "$w" ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i + 1)); done
}
IA=$(T display -p -t "$W_API" '#{window_index}')

AGENT_KIND=codex "$AS" set working "$P_API"
is "codex shows the hexagon"            "$(gsum)" "⬢$IA "
is "working is coloured yellow"         "$(rawsum)" "#[fg=yellow]⬢$IA#[default] "
AGENT_KIND=pi "$AS" set blocked "$P_API"
is "pi shows pi"                        "$(gsum)" "π$IA "
is "blocked is coloured colour208"      "$(rawsum)" "#[fg=colour208]π$IA#[default] "
"$AS" set ask "$P_API"
is "no AGENT_KIND reports as kind agent" "$(T display -p -t "$P_API" '#{@agent_kind}')" agent
is "kind agent shows the dot"           "$(gsum)" "●$IA "
is "ask is coloured colour213"          "$(rawsum)" "#[fg=colour213]●$IA#[default] "
T set-option -g @agent_signal_glyph_codex X
AGENT_KIND=codex "$AS" set working "$P_API"
is "a custom codex glyph is honoured"   "$(gsum)" "X$IA "
T set-option -gu @agent_signal_glyph_codex
hook "$P_API" SessionStart
is "idle after SessionStart keeps the pane in the summary" "$(gsum)" "✳$IA "
is "idle is coloured colour245"         "$(rawsum)" "#[fg=colour245]✳$IA#[default] "
hook "$P_API" SessionEnd
is "SessionEnd drops the pane from the summary" "$(gsum)" ""

# @agent_needs counts windows, not panes.
hook "$P_API" PermissionRequest; hook "$P_WEB" PermissionRequest
is "two blocked windows need you"       "$(gneeds)" 2
hook "$P_API" SessionEnd
hook "$P_WEB2" PreToolUse '{"tool_name":"AskUserQuestion"}'
is "ask and blocked in one window count once" "$(gneeds)" 1
hook "$P_WEB" SessionEnd; hook "$P_WEB2" SessionEnd
is "nothing waiting: the count is unset" "$(gneeds)" ""

# A window killed while blocked: the window-unlinked hook recomputes.
W_K=$(T new-window -d -n doomed -P -F '#{window_id}'); P_K=$(T list-panes -t "$W_K" -F '#{pane_id}')
hook "$P_K" PermissionRequest
is "a blocked window in a new window counts" "$(gneeds)" 1
T kill-window -t "$W_K"; waitcmd "" gneeds
is "killing a blocked window clears the count (window-unlinked hook)" "$(gneeds)" ""
is "and drops its glyph"                "$(gsum)" ""

# A blocked pane killed out of a two-pane window: the after-kill-pane hook.
P_K2=$(T split-window -d -t "$W_API" -P -F '#{pane_id}')
hook "$P_K2" PermissionRequest
T kill-pane -t "$P_K2"; waitcmd "" gneeds
is "killing a blocked pane clears the count (after-kill-pane hook)" "$(gneeds)" ""

# remain-on-exit: the agent's process dies but its pane stays, dead. The
# summary skips dead panes, but only when something recomputes it.
W_D=$(T new-window -d -n dying -P -F '#{window_id}' cat)
T set-option -w -t "$W_D" remain-on-exit on
P_D=$(T list-panes -t "$W_D" -F '#{pane_id}')
AGENT_KIND=codex "$AS" set blocked "$P_D"
ID=$(T display -p -t "$W_D" '#{window_index}')
is "the soon-dead pane is in the summary" "$(gsum)" "⬢$ID "
T send-keys -t "$P_D" C-d   # cat reads EOF and exits
waitcmd 1 T display -p -t "$P_D" '#{pane_dead}'
is "its process exited, the pane remains (dead)" "$(T display -p -t "$P_D" '#{pane_dead}')" 1
waitcmd "" gsum
# tmux 3.4 only collects a dead pane's exit status, and so only fires
# pane-died, on its next SIGCHLD; 3.5 signals itself (server_destroy_pane).
# One throwaway job supplies that SIGCHLD. Any later tmux has fired by now.
if [ -n "$(gsum)" ]; then T run-shell -b true; waitcmd "" gsum; echo "  note tmux $(T display -p '#{version}') fired pane-died only after another child exited"; fi
is "the pane-died hook drops a dead pane's glyph" "$(gsum)" ""
is "and its needs-you count"            "$(gneeds)" ""

finish
