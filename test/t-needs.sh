#!/bin/sh
# The needs-you count (@agent_needs) as windows and panes come and go, and
# the agent kind recorded by `set`.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup
unset AGENT_KIND
HOME=$TMPDIR; export HOME   # SessionStart syncs from ~/.claude/sessions: keep the real one out

# Poll a command's output until it equals <want> (async hooks), at most ~10s.
waitcmd() { # waitcmd <want> <cmd...>
  w=$1; shift; i=0
  while [ "$("$@")" != "$w" ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i + 1)); done
}
AGENT_KIND=codex "$AS" set working "$P_API"
is "AGENT_KIND is recorded on the pane"  "$(T display -p -t "$P_API" '#{@agent_kind}')" codex
is "working does not need you"           "$(gneeds)" ""
AGENT_KIND=pi "$AS" set blocked "$P_API"
is "blocked needs you"                   "$(gneeds)" 1
"$AS" set ask "$P_API"
is "no AGENT_KIND reports as kind agent" "$(T display -p -t "$P_API" '#{@agent_kind}')" agent
is "ask needs you"                       "$(gneeds)" 1
hook "$P_API" SessionEnd
is "SessionEnd clears the count"         "$(gneeds)" ""

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

# A blocked pane killed out of a two-pane window: the after-kill-pane hook.
P_K2=$(T split-window -d -t "$W_API" -P -F '#{pane_id}')
hook "$P_K2" PermissionRequest
T kill-pane -t "$P_K2"; waitcmd "" gneeds
is "killing a blocked pane clears the count (after-kill-pane hook)" "$(gneeds)" ""

# remain-on-exit: the agent's process dies but its pane stays, dead. The
# count skips dead panes, but only when something recomputes it.
W_D=$(T new-window -d -n dying -P -F '#{window_id}' cat)
T set-option -w -t "$W_D" remain-on-exit on
P_D=$(T list-panes -t "$W_D" -F '#{pane_id}')
AGENT_KIND=codex "$AS" set blocked "$P_D"
is "the soon-dead pane counts"          "$(gneeds)" 1
T send-keys -t "$P_D" C-d   # cat reads EOF and exits
waitcmd 1 T display -p -t "$P_D" '#{pane_dead}'
is "its process exited, the pane remains (dead)" "$(T display -p -t "$P_D" '#{pane_dead}')" 1
waitcmd "" gneeds
# tmux 3.4 only collects a dead pane's exit status, and so only fires
# pane-died, on its next SIGCHLD; 3.5 signals itself (server_destroy_pane).
# One throwaway job supplies that SIGCHLD. Any later tmux has fired by now.
if [ -n "$(gneeds)" ]; then T run-shell -b true; waitcmd "" gneeds; echo "  note tmux $(T display -p '#{version}') fired pane-died only after another child exited"; fi
is "the pane-died hook drops a dead pane from the count" "$(gneeds)" ""

finish
