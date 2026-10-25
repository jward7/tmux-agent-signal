#!/bin/sh
# @agent_signal_title: the entry file turns on the outer terminal's title and
# points it at the needs-you count, or at a format of your own. Off, it leaves
# set-titles alone.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

DEFAULT_FMT='#{?@agent_needs,[#{@agent_needs} need you] ,}#S:#W'

"$AS" uninstall >/dev/null
T set-option -g set-titles off
before=$(T show-option -gv set-titles-string)
sh "$ROOT/agent-signal.tmux"
is "title off (the default): set-titles is left off"       "$(T show-option -gv set-titles)" off
is "title off: set-titles-string is left as it was"         "$(T show-option -gv set-titles-string)" "$before"

T set-option -g @agent_signal_title on
sh "$ROOT/agent-signal.tmux"
is "title on: set-titles is turned on"                      "$(T show-option -gv set-titles)" on
is "title on: set-titles-string is the needs-you format"    "$(T show-option -gv set-titles-string)" "$DEFAULT_FMT"

T set-option -g @agent_signal_title_format 'X #S'
sh "$ROOT/agent-signal.tmux"
is "a custom @agent_signal_title_format is used"            "$(T show-option -gv set-titles-string)" 'X #S'

hook "$P_API" PermissionRequest
T set-option -g set-titles-string "$DEFAULT_FMT"
is "the default format renders the count"                   "$(T display -p -t "$W_API" "$DEFAULT_FMT")" "[1 need you] main:api"

finish
