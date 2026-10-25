#!/bin/sh
# The entry file: window formats, key bindings, hooks, idempotency.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

is "window-status-format is the plugin's"         "$(T show-option -gv window-status-format)" "$("$AS" window-format)"
is "window-status-current-format is the same"     "$(T show-option -gv window-status-current-format)" "$("$AS" window-format)"
is "the format found at load is kept for uninstall" "$(T show-option -gv @agent_saved_window-status-format)" '#I:#W#{?window_flags,#{window_flags}, }'
is "the badge comes before the window name"       "$("$AS" window-format | awk '{print (index($0, "@agent_icon") < index($0, "#I:#W"))}')" 1
is "status-right is left alone"                   "$(T show-option -gv status-right | grep -c agent)" 0
is "next key bound"      "$(T list-keys -T prefix | grep -c 'agent-signal next')" 1
is "seen hook installed" "$(T show-hooks -g | grep -c 'after-select-window\[91\]')" 1

sh "$ROOT/agent-signal.tmux"
is "sourcing the entry file twice leaves the format as it was"  "$(T show-option -gv window-status-format)" "$("$AS" window-format)"
is "and does not overwrite the saved format with the plugin's" "$(T show-option -gv @agent_saved_window-status-format | grep -c agent_icon)" 0

is "the command path is published for other agents to find" "$(T show-option -gv @agent_signal_command)" "$AS"

# Upgrading from 0.4: the old appended badge and summary prefix are migrated.
"$AS" uninstall >/dev/null
OLD='#{?#{@agent_icon}, #[fg=#{@agent_fg}#,bold]#{@agent_icon}#[default],}'
T set-option -g window-status-format "#W THEMED$OLD"; T set-option -g status-right "#{@agent_summary}clock"
T set-option -g @agent_summary "x1"
sh "$ROOT/agent-signal.tmux"
is "0.4's appended badge is replaced by the new format" "$(T show-option -gv window-status-format)" "$("$AS" window-format)"
is "and the theme's format under it is what uninstall will restore" "$(T show-option -gv @agent_saved_window-status-format)" "#W THEMED"
is "0.4's summary prefix is stripped from status-right"  "$(T show-option -gv status-right)" clock
is "and the old summary option is unset"                 "$(T show-option -gqv @agent_summary)" ""

"$AS" uninstall >/dev/null
hook "$P_API" PermissionRequest
is "a hook before the entry file ran wires the server itself" "$(T show-option -gv window-status-format)" "$("$AS" window-format)"
is "and the event is not lost" "$(wst "$W_API")" blocked
hook "$P_API" SessionEnd

finish
