#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# Without jq on PATH the sed/grep fallbacks must read the same JSON.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

NOJQ=$(mktemp -d); for b in sh cat tmux awk sed grep tr head cut sort ls mkdir rmdir sleep id dirname date; do ln -s "$(command -v "$b")" "$NOJQ/$b"; done
nojq() { printf '%s' "$3" | PATH=$NOJQ TMUX_PANE=$1 "$AS" hook "$2"; }
nojq "$P_API" PreToolUse '{ "tool_name" : "AskUserQuestion" }'
is "sed fallback reads spaced JSON -> ask"        "$(wst "$W_API")" ask
nojq "$P_API" Stop '{"background_tasks": [ {"id": "x"} ]}'
is "sed fallback sees a non-empty task array"     "$(wst "$W_API")" working
nojq "$P_API" Stop '{"background_tasks": []}'
is "sed fallback sees an empty task array -> done" "$(wst "$W_API")" done

nojq "$P_API" UserPromptSubmit '{}'
nojq "$P_API" SessionStart '{"source": "compact"}'
is "sed fallback reads .source: compaction leaves a working pane working" "$(pst "$P_API")" working
nojq "$P_API" Notification '{"notification_type": "permission_prompt"}'
is "sed fallback reads .notification_type permission_prompt -> blocked" "$(pst "$P_API")" blocked
nojq "$P_API" UserPromptSubmit '{}'
nojq "$P_API" Notification '{"notification_type": "elicitation_dialog"}'
is "sed fallback reads .notification_type elicitation_dialog -> ask" "$(pst "$P_API")" ask
nojq "$P_API" UserPromptSubmit '{}'
nojq "$P_API" Notification '{"notification_type": "idle_prompt"}'
is "sed fallback reads .notification_type idle_prompt: a working pane -> done" "$(pst "$P_API")" done

# The top-level key is the one that counts, not one nested in tool_input, and
# string values before the key (session_id, cwd) must not throw the match off.
nojq "$P_API" PreToolUse '{"session_id":"abc","cwd":"/x","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"x","tool_name":"AskUserQuestion"}}'
is "sed fallback: a nested tool_name does not beat the top-level one" "$(pst "$P_API")" working
nojq "$P_API" PreToolUse '{"session_id":"abc","tool_name":"AskUserQuestion","tool_input":{"question":"x"}}'
is "sed fallback: a realistic AskUserQuestion payload -> ask" "$(pst "$P_API")" ask
# A whitespace-only array is empty (a tab between the brackets is not an element).
nojq "$P_API" UserPromptSubmit '{}'
nojq "$P_API" Stop "$(printf '{"background_tasks":[\t]}')"
is "sed fallback: a tab-only task array is empty -> done" "$(pst "$P_API")" done
hook "$P_API" SessionEnd; rm -rf "$NOJQ"

finish
