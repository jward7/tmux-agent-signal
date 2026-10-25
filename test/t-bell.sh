#!/bin/sh
# @agent_signal_bell: a wait on you rings tmux's own bell in the agent's pane,
# so monitor-bell flags the window (and an SSH'd terminal hears it). A finish
# does not ring, and with the option off nothing does.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

bflag() { T display -p -t "$1" '#{window_bell_flag}'; }
waitbell() { i=0; while [ "$(bflag "$1")" != 1 ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i + 1)); done; }

is "monitor-bell is on (tmux default)" "$(T show-option -gv monitor-bell)" on

# Negatives first, each followed by a short settle: tmux reads pane output on
# its own schedule, so "no flag yet" is only meaningful after a pause.
hook "$P_WEB" PermissionRequest; sleep 0.4
is "bell off (the default): blocked does not ring" "$(bflag "$W_WEB")" 0
hook "$P_WEB" SessionEnd

T set-option -g @agent_signal_bell on
hook "$P_WEB" Stop; sleep 0.4
is "bell on: a finish (done) does not ring" "$(bflag "$W_WEB")" 0

hook "$P_API" PermissionRequest; waitbell "$W_API"
is "bell on: blocked in a background window sets its bell flag" "$(bflag "$W_API")" 1

hook "$P_WEB2" PreToolUse '{"tool_name":"AskUserQuestion"}'; waitbell "$W_WEB"
is "bell on: ask rings too" "$(bflag "$W_WEB")" 1

finish
