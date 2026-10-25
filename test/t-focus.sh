#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# "On screen" means a focused client is showing the window, not merely that
# its session is attached: with one session per terminal tab every session is
# attached, but only the focused tab is looked at. A real client on a
# pseudo-terminal, with focus reported the way a terminal does it.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup
T set-option -g focus-events on
T select-window -t "$W_API"
attach_client main

is "the attached client starts out focused" \
  "$(T list-clients -F '#{client_flags}' | grep -c focused)" 1

drive_done "$P_API"
is "finishing in the window a focused client shows: no done flag" "$(wst "$W_API")" ""

focus out
drive_done "$P_API"
is "finishing while the terminal is unfocused (session still attached): done shows" "$(wst "$W_API")" done

focus in; waitfor "$W_API" ""
is "focusing the terminal again clears that done (client-focus-in hook)" "$(wst "$W_API")" ""
is "client-focus-in seen hook installed" "$(T show-hooks -g | grep -c 'client-focus-in\[91\]')" 1

drive_done "$P_WEB"
is "a window the focused client is not showing still gets done" "$(wst "$W_WEB")" done

finish
