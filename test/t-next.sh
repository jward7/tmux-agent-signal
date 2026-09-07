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

finish
