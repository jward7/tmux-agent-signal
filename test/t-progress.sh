#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# The terminal progress bar (OSC 9;4): one value per client, from the window it
# shows, written only to terminals known to draw it. `progress print` shows
# what would be written without writing it.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

prog() { "$AS" progress print | cut -f2; }

is "no client attached: nothing to write"                  "$("$AS" progress print)" ""

attach_client main
# The test client's "terminal" is another tmux; wait for its version reply.
i=0; while [ -z "$(T list-clients -F '#{client_termtype}')" ] && [ $i -lt 100 ]; do sleep 0.05; i=$((i + 1)); done
type=$(T list-clients -F '#{client_termtype}')

is "a terminal not in the list gets nothing (graceful)"    "$("$AS" progress print)" ""
hook "$P_WEB" UserPromptSubmit
is "and an event writes nothing for it either"             "$("$AS" progress print)" ""

T set-option -g @agent_signal_progress_terminals '^tmux '
case $type in tmux*) ok "the client named its terminal ($type)" ;; *) bad "the client named its terminal" "$type" "tmux ..." ;; esac

T select-window -t "$W_WEB"
is "one of two panes working, none finished: moving bar" "$(prog)" "3;0"
hook "$P_WEB2" UserPromptSubmit; hook "$P_WEB2" Stop
is "one of two finished: half full"                      "$(prog)" "1;50"
hook "$P_WEB2" PermissionRequest
is "a blocked pane turns it red"                         "$(prog)" "2;100"
hook "$P_WEB2" PreToolUse '{"tool_name":"AskUserQuestion"}'
is "a question turns it yellow"                          "$(prog)" "4;100"
hook "$P_WEB2" Stop
is "back to half once it finishes"                       "$(prog)" "1;50"
hook "$P_WEB" Stop
is "all finished in front of you: cleared"               "$(prog)" "0;0"

# The bar follows the window on screen.
hook "$P_API" PermissionRequest
is "a blocked window elsewhere does not show in window scope" "$(prog)" "0;0"
T set-option -g @agent_signal_progress server
is "server scope shows it"                               "$(prog)" "2;100"
T set-option -g @agent_signal_progress window
T select-window -t "$W_API"
is "switching to that window shows it"                   "$(prog)" "2;100"

# Four agents in one window fill in quarters.
for _ in 1 2 3; do T split-window -d -t "$W_API"; done
# shellcheck disable=SC2046  # pane ids, split on purpose
set -- $(T list-panes -t "$W_API" -F '#{pane_id}')
for p in "$@"; do hook "$p" UserPromptSubmit; done
hook "$1" Stop
is "one of four finished: a quarter"                     "$(prog)" "1;25"
hook "$2" Stop; hook "$3" Stop
is "three of four finished"                              "$(prog)" "1;75"
T split-window -d -t "$W_API"
is "a plain shell pane does not count as an agent"       "$(prog)" "1;75"

T set-option -g @agent_signal_progress off
is "off: nothing is written"                             "$("$AS" progress print)" ""
"$AS" progress clear; is "clearing (what uninstall does) still works while off" "$?" 0
T set-option -g @agent_signal_progress window

# The real write goes to the client's tty and must never fail the hook.
T set-option -g @agent_signal_progress_terminals '.'
"$AS" progress; is "writing to the tty succeeds"         "$?" 0
hook "$4" Stop; is "a hook with a progress write succeeds" "$?" 0

finish
