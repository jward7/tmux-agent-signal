#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# Several panes in one window, and not stepping on a user's or theme's styling.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

T select-window -t "$W_WEB"

# --- theme safety ---
T set-option -w -t "$W_WEB" window-status-style 'fg=cyan,bg=blue'
hook "$P_WEB" UserPromptSubmit
is "a user's per-window style survives a working state" "$(wstyle "$W_WEB")" "fg=cyan,bg=blue"
hook "$P_WEB" PermissionRequest
is "blocked overrides it while flagged"  "$(wstyle "$W_WEB")" "fg=black,bg=colour208,bold"
hook "$P_WEB" SessionEnd
is "clearing removes only our style"    "$(wstyle "$W_WEB")" ""
T set-option -uw -t "$W_WEB" window-status-style

# --- multi-pane aggregation ---
hook "$P_WEB" UserPromptSubmit
hook "$P_WEB2" PermissionRequest
is "blocked pane outranks working pane" "$(wst "$W_WEB")" blocked
hook "$P_WEB" PermissionRequest
is "two blocked panes in one window count as one window needing you" "$(gneeds)" 1
hook "$P_WEB2" PostToolUse
hook "$P_WEB" Stop
is "done outranks working"           "$(wst "$W_WEB")" done
hook "$P_WEB2" Stop
hook "$P_WEB" SessionEnd
is "SessionEnd clears its pane only" "$(pst "$P_WEB")" ""
is "window keeps the other pane's state" "$(wst "$W_WEB")" done

T set-option -g @agent_signal_tab_colour needs
hook "$P_API" Stop
is "tab colour 'needs': done shows the badge only"   "$(wstyle "$W_API")" ""
hook "$P_API" PermissionRequest
is "tab colour 'needs': blocked colours the tab"     "$(wstyle "$W_API")" "fg=black,bg=colour208,bold"
T set-option -g @agent_signal_tab_colour off
hook "$P_API" Stop; hook "$P_API" PermissionRequest
is "tab colour 'off': never colours the tab"         "$(wstyle "$W_API")" ""
T set-option -g @agent_signal_tab_colour on
hook "$P_API" Stop
is "tab colour 'on' still means all"                 "$(wstyle "$W_API")" "fg=black,bg=green,bold"
hook "$P_API" SessionEnd; T set-option -gu @agent_signal_tab_colour

finish
