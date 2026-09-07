#!/bin/sh
# Awkward names: a session name with a space must not break the window scan.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

T rename-session -t main 'my proj'
hook "$P_WEB2" PermissionRequest; T select-window -t "$W_API"
"$AS" next
is "next finds a blocked window in a session whose name has a space" "$(T display -p '#{window_id}')" "$W_WEB"
hook "$P_WEB2" Stop; T select-window -t "$W_API"; waitfor "$W_API" ""
T rename-session -t 'my proj' main

finish
