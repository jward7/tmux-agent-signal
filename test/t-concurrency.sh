#!/bin/sh
# Claude runs hooks concurrently: two panes of one window must not lose a state.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

# Two hooks for panes in the same window racing: the blocked one must win.
W_RACE=$(T new-window -d -n race -P -F '#{window_id}')
P_R1=$(T list-panes -t "$W_RACE" -F '#{pane_id}'); P_R2=$(T split-window -d -t "$W_RACE" -P -F '#{pane_id}')
i=0; while [ $i -lt 10 ]; do
  hook "$P_R1" PostToolUse & hook "$P_R2" PermissionRequest & wait
  [ "$(wst "$W_RACE")" = blocked ] || break
  hook "$P_R2" PostToolUse; i=$((i + 1))
done
is "10 racing PostToolUse/PermissionRequest rounds all ended blocked" "$i" 10
hook "$P_R1" SessionEnd; hook "$P_R2" SessionEnd; T kill-window -t "$W_RACE"
is "no lock directories left behind" "$(leftovers 'agent-signal.*.lock.*')" 0

finish
