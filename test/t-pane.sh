#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# Which pane a report lands in when the caller does not say.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

# The client (none attached) and the active window are "shell"; the report
# comes from a process inside the api pane with TMUX_PANE withheld, the way
# Claude sometimes runs a hook. Process ancestry must find the api pane.
# respawn-pane runs the command as the pane's own process, so there is no
# interactive shell to wait for; sleep keeps the pane alive afterwards.
T respawn-pane -k -t "$P_API" "TMUX_PANE= '$AS' set working; sleep 60"
waitfor "$W_API" working
is "no TMUX_PANE: ancestry finds the pane the shell runs in" "$(wst "$W_API")" working
is "no TMUX_PANE: the active window is left alone"           "$(wst "$(T display -p '#{window_id}')")" ""

# An explicit pane argument wins over everything.
T respawn-pane -k -t "$P_API" "TMUX_PANE= '$AS' set blocked $P_WEB; sleep 60"
waitfor "$W_WEB" blocked
is "an explicit pane argument wins"                           "$(wst "$W_WEB")" blocked
is "and the caller's own pane is untouched"                   "$(wst "$W_API")" working

# A dead pane keeps its pid, which a later process may inherit. A pid
# collision cannot be forced here, so this only checks that a report made
# with a dead pane present still lands on the live one and never on the dead.
T set-option -g remain-on-exit on
P_DEAD=$(T new-window -d -P -F '#{pane_id}' 'exit 0')
i=0; while [ "$(T display -p -t "$P_DEAD" '#{pane_dead}')" != 1 ] && [ $i -lt 100 ]; do sleep 0.05; i=$((i + 1)); done
is "the fixture has a dead pane"                             "$(T display -p -t "$P_DEAD" '#{pane_dead}')" 1
T respawn-pane -k -t "$P_WEB2" "TMUX_PANE= '$AS' set working; sleep 60"
waitfor "$W_WEB" working
is "dead panes are never matched by ancestry"                "$(T display -p -t "$P_DEAD" '#{?@agent_pane_state,set,unset}')" unset
T kill-window -t "$(T display -p -t "$P_DEAD" '#{window_id}')"

# Outside any pane's process tree the active pane is the last resort.
is "no ancestry: falls back to the active pane" "$(TMUX_PANE='' "$AS" set done >/dev/null 2>&1; wst "$(T display -p '#{window_id}')")" done

finish
