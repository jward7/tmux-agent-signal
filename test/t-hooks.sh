#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# Claude hook event -> state mapping, tab colours and the needs-you count.
# No client is attached to this server, so nobody is looking at any window:
# "done" is always flagged, never auto-acknowledged.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

hook "$P_API" SessionStart
is "SessionStart -> idle"            "$(wst "$W_API")" ""
hook "$P_API" UserPromptSubmit
is "UserPromptSubmit -> working"     "$(wst "$W_API")" working
is "working icon"                    "$(wicon "$W_API")" "~"
is "working leaves tab colour alone" "$(wstyle "$W_API")" ""
hook "$P_API" PreToolUse '{"tool_name":"Bash"}'
is "PreToolUse Bash -> working"      "$(wst "$W_API")" working
hook "$P_API" PreToolUse '{"tool_name":"AskUserQuestion"}'
is "PreToolUse AskUserQuestion -> ask" "$(wst "$W_API")" ask
is "ask counts as needing you"       "$(gneeds)" 1
hook "$P_API" PostToolUse '{"tool_name":"AskUserQuestion"}'
is "PostToolUse -> working"          "$(wst "$W_API")" working
hook "$P_API" PermissionRequest
is "PermissionRequest -> blocked"    "$(wst "$W_API")" blocked
is "blocked colours the tab"         "$(wstyle "$W_API")" "fg=black,bg=colour208,bold"
hook "$P_API" Notification '{"notification_type":"permission_prompt"}'
is "Notification permission_prompt -> blocked" "$(wst "$W_API")" blocked
hook "$P_API" Stop '{"background_tasks":[{"id":"x"}]}'
is "Stop with background task -> working" "$(wst "$W_API")" working
hook "$P_API" Stop '{"background_tasks":[]}'
is "Stop -> done (detached server: nobody is looking)" "$(wst "$W_API")" done
is "done colours the tab green"      "$(wstyle "$W_API")" "fg=black,bg=green,bold"
is "done does not count as needing you" "$(gneeds)" ""

finish
