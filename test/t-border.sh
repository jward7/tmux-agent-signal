#!/bin/sh
# Pane borders: the border style follows the pane's state, on top of the user's own style.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

border() { T display -p -t "$1" '#{E:pane-border-style}'; }
active() { T display -p -t "$1" '#{E:pane-active-border-style}'; }
# tmux's own defaults, as the entry file found them: "default" and "fg=green"
# up to tmux 3.7, theme colours from 3.8, where the active one is itself a
# format, so expand them the way the border styles are expanded.
base=$(T display -p -t "$P_WEB" '#{E:@agent_saved_pane-border-style}')
abase=$(T display -p -t "$P_WEB" '#{E:@agent_saved_pane-active-border-style}')

is "the user's base style is kept in front"     "$(border "$P_WEB")" "$base"
hook "$P_WEB" UserPromptSubmit
is "working adds nothing"                        "$(border "$P_WEB")" "$base"
hook "$P_WEB" PermissionRequest
is "blocked appends orange"                      "$(border "$P_WEB")" "$base,fg=colour208"
is "and the other pane in the window is untouched" "$(border "$P_WEB2")" "$base"
is "the active border style gets the same colour" "$(active "$P_WEB")" "$abase,fg=colour208"
hook "$P_WEB" PreToolUse '{"tool_name":"AskUserQuestion"}'
is "ask appends pink"                            "$(border "$P_WEB")" "$base,fg=colour213"
hook "$P_WEB" Stop
is "done appends green"                          "$(border "$P_WEB")" "$base,fg=green"
"$AS" seen "$W_WEB"
is "seen clears it"                              "$(border "$P_WEB")" "$base"
hook "$P_WEB" SessionEnd

# A theme's own style, with a comma, survives as the base.
"$AS" uninstall >/dev/null
T set-option -g pane-border-style 'fg=blue,bold'
sh "$ROOT/agent-signal.tmux"
hook "$P_API" PermissionRequest
is "a theme's style stays as the base under the state colour" "$(border "$P_API")" "fg=blue,bold,fg=colour208"
is "and is what uninstall will restore" "$(T show-option -gv @agent_saved_pane-border-style)" "fg=blue,bold"
hook "$P_API" SessionEnd
"$AS" uninstall >/dev/null
is "uninstall puts the theme's border style back" "$(T show-option -gv pane-border-style)" "fg=blue,bold"
sh "$ROOT/agent-signal.tmux"

finish
