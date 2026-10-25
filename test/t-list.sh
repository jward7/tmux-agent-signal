#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# `agent-signal list`, the tree the switcher popup renders.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

hook "$P_API" UserPromptSubmit   # api: working (a marked window)
hook "$P_WEB2" PermissionRequest # web: blocked (a marked window; shell stays unmarked)

is "list has session, window and pane rows" "$("$AS" list | cut -f1 | sort -u | tr -d '\n')" "PSW"
# ~ and ! are single bytes, so index() measures columns and not bytes
is "window rows share one column for the index" "$("$AS" list | awk -F'\t' '$1 == "W" {print index($3, ":")}' | sort -u | wc -l | tr -d ' ')" 1
is "a marked and an unmarked window row align" "$("$AS" list | awk -F'\t' '$1 == "W" {print (substr($3, 1, 1) == " ")}' | sort -u | wc -l | tr -d ' ')" 2
hook "$P_WEB2" Stop              # web: done

T rename-window -t "$W_WEB" ''
is "list survives an empty window name" "$("$AS" list 2>&1 | grep -c 'integer expression')" 0
T rename-window -t "$W_WEB" web

HOME=$TMPDIR; export HOME   # list syncs from ~/.claude/sessions: keep the real one out
row() { "$AS" list | awk -F'\t' -v k="$1" -v t="$2" '$1 == k && $2 == t {print $3}'; }   # row <kind> <target>

# The S row's mark is the session's most urgent tier.
for s in sb sa sd sw si; do T new-session -d -s "$s"; done
"$AS" set blocked "$(T list-panes -t sb -F '#{pane_id}')"
"$AS" set ask     "$(T list-panes -t sa -F '#{pane_id}')"
"$AS" set done    "$(T list-panes -t sd -F '#{pane_id}')"
"$AS" set working "$(T list-panes -t sw -F '#{pane_id}')"
is "S row marks: ! blocked, ? ask, + done, ~ working, blank idle" \
  "$(for s in sb sa sd sw si; do row S "$s"; done | tr '\n' '|')" "! sb|? sa|+ sd|~ sw|  si|"
is "S row mark: done beats working within a session" "$(row S main)" "+ main"
hook "$P_WEB" PermissionRequest
is "S row mark: blocked beats done and working"     "$(row S main)" "! main"
hook "$P_WEB" SessionEnd
for s in sb sa sd sw si; do T kill-session -t "$s"; done

IA=$(T display -p -t "$W_API" '#{window_index}')
"$AS" hold park "$W_API"
is "a parked window's W row has the park mark and suffix" "$(row W "$W_API")" "p    $IA:api (park)"
"$AS" hold clear "$W_API"

# P row label: @agent_name, else @agent_kind, else the running command.
P_WEB3=$(T split-window -d -t "$W_WEB" -P -F '#{pane_id}')
T set-option -p -t "$P_WEB" @agent_name alice; T set-option -p -t "$P_WEB" @agent_kind claude
label() { row P "$1" | sed 's/^[^:]*: //'; }
is "P row label: @agent_name first"            "$(label "$P_WEB")" alice
is "P row label: then @agent_kind"             "$(label "$P_WEB2")" claude
is "P row label: then pane_current_command"    "$(label "$P_WEB3")" "$(T display -p -t "$P_WEB3" '#{?pane_current_command,#{pane_current_command},-}')"
T kill-pane -t "$P_WEB3"; T set-option -up -t "$P_WEB" @agent_name; T set-option -up -t "$P_WEB" @agent_kind

# P rows: only for a window with more than one pane or a state.
P_SHELL=$(T list-panes -t main:shell -F '#{pane_id}')
is "no P row for a lone pane in a stateless window" "$("$AS" list | awk -F'\t' -v p="$P_SHELL" '$1 == "P" && $2 == p' | wc -l | tr -d ' ')" 0
is "a P row for a lone pane in a window with state" "$("$AS" list | awk -F'\t' -v p="$P_API" '$1 == "P" && $2 == p' | wc -l | tr -d ' ')" 1
is "P rows for every pane of a two-pane window"     "$("$AS" list | awk -F'\t' -v a="$P_WEB" -v b="$P_WEB2" '$1 == "P" && ($2 == a || $2 == b)' | wc -l | tr -d ' ')" 2
hook "$P_API" SessionEnd
is "the lone pane's P row goes when its state does" "$("$AS" list | awk -F'\t' -v p="$P_API" '$1 == "P" && $2 == p' | wc -l | tr -d ' ')" 0

# Field 2 is what the switcher hands to switch-client / select-window /
# select-pane: a session name, a window @id, a pane %id, each one tmux resolves.
T new-session -d -s 'my proj'
# resolves <format> <target>: 0 if tmux maps <target> back to itself
resolves() { [ "$(T display -p -t "$2" "$1" 2>/dev/null)" = "$2" ]; }
badtarget() { # badtarget <kind> <target>: prints the row if the switcher could not use it
  case $1 in
    S) resolves '#{session_name}' "$2" && return ;;
    W) case $2 in @*[!0-9]*|@) ;; @*) resolves '#{window_id}' "$2" && return ;; esac ;;
    P) case $2 in %*[!0-9]*|%) ;; %*) resolves '#{pane_id}' "$2" && return ;; esac ;;
  esac
  echo "$1 $2"
}
badrows=$("$AS" list | while IFS='	' read -r k tgt _; do badtarget "$k" "$tgt"; done)
is "every row's target is a session name, @id or %id that tmux resolves" "$badrows" ""
is "a session name with a space is a whole target" "$(row S 'my proj')" "  my proj"
T kill-session -t 'my proj'

finish
