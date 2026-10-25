#!/bin/sh
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

# Outside any pane's process tree the active pane is the last resort.
is "no ancestry: falls back to the active pane" "$(TMUX_PANE= "$AS" set done >/dev/null 2>&1; wst "$(T display -p '#{window_id}')")" done

finish
