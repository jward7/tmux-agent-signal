#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# Viewing a window acknowledges it: the after-select-window hook, an explicit
# window argument, and the "nobody is looking" case of a detached session.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

drive_done "$P_API"
T select-window -t "$W_API"; waitfor "$W_API" ""
is "viewing a done window clears it (after-select-window hook)" "$(wst "$W_API")" ""
is "all three seen hooks name their own window" "$(T show-hooks -g | grep -c 'seen #{window_id}')" 3
hook "$P_WEB" Stop
"$AS" seen "$W_WEB"
is "seen with an explicit window clears that window" "$(wst "$W_WEB")" ""
drive_done "$P_API"
# No client is attached to the test server, so nobody is "looking": done must show.
is "finishing in the active window of a detached session still shows done" "$(wst "$W_API")" done

finish
