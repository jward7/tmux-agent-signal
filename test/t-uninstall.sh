#!/bin/sh
# `uninstall` is the exact inverse of the entry file, and reinstall works after it.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

hook "$P_API" PermissionRequest
"$AS" uninstall >/dev/null
is "uninstall strips the badge from window-status-format" "$(T show-option -gv window-status-format | grep -c agent_icon)" 0
is "uninstall strips the summary from status-right"       "$(T show-option -gv status-right | grep -c agent_summary)" 0
is "uninstall removes the hooks"                          "$(T show-hooks -g | grep -c agent-signal)" 0
is "uninstall removes the key bindings"                   "$(T list-keys | grep -c agent-signal)" 0
is "uninstall clears window state and style"              "$(wst "$W_API")$(wstyle "$W_API")" ""
sh "$ROOT/agent-signal.tmux"
is "reinstall after uninstall restores the badge once"    "$(T show-option -gv window-status-format | grep -o agent_icon | wc -l | tr -d ' ')" 2

finish
