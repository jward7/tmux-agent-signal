#!/bin/sh
# `uninstall` is the exact inverse of the entry file, and reinstall works after it.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

T set-option -g @agent_signal_title on; sh "$ROOT/agent-signal.tmux"   # set-titles on, our format
T set-option -w -t "$W_WEB" window-status-format '#I:#W'                # a theme's per-window format
hook "$P_WEB" Stop                                                       # ... which the next event mends
hook "$P_API" PermissionRequest
"$AS" hold wait "$W_API"
T set-option -p -t "$P_API" @agent_name alice
wopts() { for o in @agent_since @agent_hold @agent_icon @agent_fg @agent_tab_owned; do printf '%s=%s ' "$o" "$(T show-option -wqv -t "$W_API" "$o")"; done; }
popts() { for o in @agent_kind @agent_name; do printf '%s=%s ' "$o" "$(T display -p -t "$P_API" "#{$o}")"; done; }
gopts() { for o in @agent_needs @agent_signal_command @agent_saved_window-status-format; do printf '%s=%s ' "$o" "$(T show-option -gqv "$o")"; done; }
is "before: every window option is set" "$(wopts | grep -c '= ')" 0
is "before: every pane option is set"   "$(popts | grep -c '= ')" 0
is "before: every global option is set" "$(gopts | grep -c '= ')" 0
is "before: the per-window format was mended" "$(T show-option -wqv -t "$W_WEB" window-status-format | grep -c agent_icon)" 1
"$AS" uninstall >/dev/null
is "uninstall unsets the window's since, hold, icon, fg and tab_owned" "$(wopts)" "@agent_since= @agent_hold= @agent_icon= @agent_fg= @agent_tab_owned= "
is "uninstall unsets the pane's kind and name" "$(popts)" "@agent_kind= @agent_name= "
is "uninstall unsets needs, the published command and the saved format" "$(gopts)" "@agent_needs= @agent_signal_command= @agent_saved_window-status-format= "
is "uninstall takes the badge back out of a mended per-window format" "$(T show-option -wqv -t "$W_WEB" window-status-format)" '#I:#W'
is "uninstall turns set-titles back off" "$(T show-option -gv set-titles)" off
is "uninstall drops its set-titles-string" "$(T show-option -gv set-titles-string | grep -c agent_needs)" 0
is "uninstall puts window-status-format back"             "$(T show-option -gv window-status-format)" '#I:#W#{?window_flags,#{window_flags}, }'
is "uninstall puts window-status-current-format back"     "$(T show-option -gv window-status-current-format)" '#I:#W#{?window_flags,#{window_flags}, }'
is "uninstall removes the hooks"                          "$(T show-hooks -g | grep -c agent-signal)" 0
is "uninstall removes the key bindings"                   "$(T list-keys | grep -c agent-signal)" 0
is "uninstall clears window state and style"              "$(wst "$W_API")$(wstyle "$W_API")" ""
sh "$ROOT/agent-signal.tmux"
is "reinstall after uninstall sets the format again"      "$(T show-option -gv window-status-format)" "$("$AS" window-format)"

# A theme's global format is what comes back, not tmux's default.
"$AS" uninstall >/dev/null
T set-option -g window-status-format '#W THEMED'
sh "$ROOT/agent-signal.tmux"
is "the plugin replaces a theme's format"                 "$(T show-option -gv window-status-format)" "$("$AS" window-format)"
"$AS" uninstall >/dev/null
is "and uninstall brings the theme's format back"         "$(T show-option -gv window-status-format)" '#W THEMED'

finish
