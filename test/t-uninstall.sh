#!/bin/sh
# `uninstall` is the exact inverse of the entry file, and reinstall works after it.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

T set-option -g @agent_signal_title on; sh "$ROOT/agent-signal.tmux"   # set-titles on, our format
T set-option -w -t "$W_WEB" window-status-format '#I:#W'                # a theme's per-window format
hook "$P_WEB" Stop                                                       # ... which the next event mends
hook "$P_API" PermissionRequest
"$AS" hold wait "$W_API"
T set-option -p -t "$P_API" @agent_name alice
wopts() { for o in @agent_since @agent_hold @agent_icon @agent_fg @agent_tab_owned; do printf '%s=%s ' "$o" "$(T show-option -wqv -t "$W_API" "$o")"; done; }
popts() { for o in @agent_kind @agent_name; do printf '%s=%s ' "$o" "$(T display -p -t "$P_API" "#{$o}")"; done; }
gopts() { for o in @agent_needs @agent_summary @agent_signal_command; do printf '%s=%s ' "$o" "$(T show-option -gqv "$o")"; done; }
is "before: every window option is set" "$(wopts | grep -c '= ')" 0
is "before: every pane option is set"   "$(popts | grep -c '= ')" 0
is "before: every global option is set" "$(gopts | grep -c '= ')" 0
is "before: the per-window format was mended" "$(T show-option -wqv -t "$W_WEB" window-status-format | grep -c agent_icon)" 1
"$AS" uninstall >/dev/null
is "uninstall unsets the window's since, hold, icon, fg and tab_owned" "$(wopts)" "@agent_since= @agent_hold= @agent_icon= @agent_fg= @agent_tab_owned= "
is "uninstall unsets the pane's kind and name" "$(popts)" "@agent_kind= @agent_name= "
is "uninstall unsets needs, summary and the published command" "$(gopts)" "@agent_needs= @agent_summary= @agent_signal_command= "
is "uninstall takes the badge back out of a mended per-window format" "$(T show-option -wqv -t "$W_WEB" window-status-format)" '#I:#W'
is "uninstall turns set-titles back off" "$(T show-option -gv set-titles)" off
is "uninstall drops its set-titles-string" "$(T show-option -gv set-titles-string | grep -c agent_needs)" 0
is "uninstall strips the badge from window-status-format" "$(T show-option -gv window-status-format | grep -c agent_icon)" 0
is "uninstall strips the summary from status-right"       "$(T show-option -gv status-right | grep -c agent_summary)" 0
is "uninstall removes the hooks"                          "$(T show-hooks -g | grep -c agent-signal)" 0
is "uninstall removes the key bindings"                   "$(T list-keys | grep -c agent-signal)" 0
is "uninstall clears window state and style"              "$(wst "$W_API")$(wstyle "$W_API")" ""
sh "$ROOT/agent-signal.tmux"
is "reinstall after uninstall restores the badge once"    "$(T show-option -gv window-status-format | grep -o agent_icon | wc -l | tr -d ' ')" 2

finish
