#!/bin/sh
# prefix+N: jump to the next window that needs you, skipping parked ones.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

T select-window -t "$W_API"
hook "$P_API" Stop                                   # api: done (detached server: nobody is looking, so it shows)
hook "$P_WEB2" PermissionRequest                     # web: blocked
"$AS" next
is "next jumps to the blocked window" "$(T display -p '#{window_id}')" "$W_WEB"
hook "$P_WEB2" Stop; T select-window -t "$W_API"; waitfor "$W_API" ""
"$AS" hold park "$W_WEB"
"$AS" next
is "next skips a parked window"      "$(T display -p '#{window_id}')" "$W_API"
"$AS" hold clear "$W_WEB"

# Two blocked windows: the one that has waited longest wins over window order.
T select-window -t main:0
hook "$P_API" PermissionRequest; hook "$P_WEB2" PermissionRequest
is "a state change is stamped"       "$(T show-option -wqv -t "$W_API" @agent_since | grep -c '^[0-9]\{10\}$')" 1
T set-option -w -t "$W_API" @agent_since 2000000000       # api blocked "later"
T set-option -w -t "$W_WEB" @agent_since 1000000000       # web has waited longer
"$AS" next
is "next serves the longest wait first" "$(T display -p '#{window_id}')" "$W_WEB"
# A third blocked window, newest of all: repeated presses must visit every
# window in age order and wrap, not bounce between the two oldest.
W_C=$(T new-window -d -n c -P -F '#{window_id}'); P_C=$(T list-panes -t "$W_C" -F '#{pane_id}')
hook "$P_C" PermissionRequest; T set-option -w -t "$W_C" @agent_since 3000000000
seq=""; for n in 1 2 3 4; do "$AS" next; seq="$seq $(T display -p '#{window_id}')"; done
is "repeated presses walk the tier oldest to newest and wrap" "$seq" " $W_API $W_C $W_WEB $W_API"
hook "$P_C" Stop; T kill-window -t "$W_C"
hook "$P_WEB2" Stop
hook "$P_API" PreToolUse '{"tool_name":"Bash"}'           # api: working again
hook "$P_API" PermissionRequest                           # blocked again, fresh stamp
is "the stamp is renewed on a new transition" "$(T show-option -wqv -t "$W_API" @agent_since | grep -c '^2000000000$')" 0
hook "$P_API" Stop; T select-window -t "$W_API"; waitfor "$W_API" ""
is "idle clears the stamp"           "$(T show-option -wqv -t "$W_API" @agent_since)" ""

finish
