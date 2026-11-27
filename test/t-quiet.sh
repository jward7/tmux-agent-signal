#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# tmux repaints every client on every option write, even of the value already
# there. An event that changes nothing (a tool call while already working, a
# status line update with the same numbers) must therefore write nothing.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

# A stand-in tmux, first on PATH, that notes each call and passes it on.
SHIM=$(mktemp -d); LOG="$TMPDIR/tmux-calls"
# shellcheck disable=SC2016  # $* and $@ belong to the stand-in script
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexec "%s" "$@"\n' "$LOG" "$(command -v tmux)" > "$SHIM/tmux"; chmod +x "$SHIM/tmux"
writes() { grep -c 'set-option\|set-hook' "$LOG"; }           # option writes since the log was last emptied
calls()  { wc -l < "$LOG" | tr -d ' '; }
ev() { : > "$LOG"; printf '%s' "${3:-{\}}" | PATH="$SHIM:$PATH" TMUX_PANE=$1 "$AS" hook "$2"; }   # ev <pane> <event> [json]

ev "$P_API" UserPromptSubmit
is "a change is written (idle -> working)"            "$([ "$(writes)" -gt 0 ] && echo yes):$(wst "$W_API")" "yes:working"
ev "$P_API" PostToolUse
is "a tool call while working writes nothing"         "$(writes):$(wst "$W_API")" "0:working"
ev "$P_API" PreToolUse '{"tool_name":"Bash"}'
is "nor does the next one"                            "$(writes)" 0
ev "$P_API" PermissionRequest
is "blocked is written, tab and all"                  "$([ "$(writes)" -gt 0 ] && echo yes):$(wst "$W_API"):$(wstyle "$W_API")" "yes:blocked:fg=black,bg=colour208,bold"
ev "$P_API" Notification '{"notification_type":"permission_prompt"}'
is "the same prompt reported twice writes nothing"    "$(writes):$(wst "$W_API")" "0:blocked"
ev "$P_API" Stop; ev "$P_API" Stop
is "a second Stop writes nothing"                     "$(writes):$(wst "$W_API")" "0:done"

# Two panes in one window: the quiet one's events do not rewrite the window.
ev "$P_WEB" PermissionRequest; ev "$P_WEB2" UserPromptSubmit; ev "$P_WEB2" PostToolUse
is "a working pane beside a blocked one writes nothing" "$(writes):$(wst "$W_WEB")" "0:blocked"

# What is skipped is only what is already right: a tab style that something
# else changed is put back by the next event, as before.
T set-option -w -t "$W_WEB" window-status-style 'fg=red'
ev "$P_WEB" PermissionRequest
is "a tab style changed behind our back is still repaired" "$(wstyle "$W_WEB")" "fg=black,bg=colour208,bold"
T set-option -g @agent_needs 7
ev "$P_WEB2" PostToolUse
is "and so is a wrong needs-you count"                "$(gneeds)" 1

: > "$LOG"; PATH="$SHIM:$PATH" "$AS" needs
is "\`needs\` with nothing to correct writes nothing"   "$(writes)" 0
: > "$LOG"; PATH="$SHIM:$PATH" "$AS" seen "$W_WEB"
is "\`seen\` on a window that is not done writes nothing" "$(writes)" 0

# --- the usage meter ---------------------------------------------------------
NOW=1800000000; R7=$((NOW + 300000))
T set-option -g @agent_signal_limits on
# statusline records in the background; the job holds fd 3, so cat returns
# when it has finished.
sl() { : > "$LOG"; printf '{"rate_limits":{"seven_day":{"used_percentage":%s,"resets_at":%s}}}\n' "$1" "$R7" | PATH="$SHIM:$PATH" AGENT_SIGNAL_NOW=${2:-$NOW} "$AS" statusline 3>&1 | cat; }
sl 36
is "the first report is written"                      "$([ "$(writes)" -gt 0 ] && echo yes):$(T show-option -gqv @agent_limits)" "yes:C w64%"
sl 36 $((NOW + 60))
is "the same report again writes nothing"             "$(writes)" 0
AGENT_SIGNAL_NOW=$((NOW + 60)); export AGENT_SIGNAL_NOW
ev "$P_API" UserPromptSubmit; ev "$P_API" PostToolUse
is "a quiet hook event writes nothing with the meter on" "$(writes)" 0
: > "$LOG"; PATH="$SHIM:$PATH" "$AS" limits
is "\`limits\` with the figure still right writes nothing" "$(writes)" 0
unset AGENT_SIGNAL_NOW
sl 37 $((NOW + 120))
is "a new figure is written"                          "$([ "$(writes)" -gt 0 ] && echo yes):$(T show-option -gqv @agent_limits)" "yes:C w63%"

# Outside tmux there is no server to ask: the status line entry asks nothing.
: > "$LOG"; out=$(printf 'x\n' | TMUX='' PATH="$SHIM:$PATH" "$AS" statusline)
is "statusline outside tmux makes no tmux call"       "$(calls):$out" "0:"
rm -rf "$SHIM"

finish
