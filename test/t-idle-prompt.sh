#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# The idle reminder Claude sends ~60s after a turn ends, and its exit code.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

# Bring the api window to done, the way the hook tests leave it.
drive_done "$P_API"

hook "$P_API" Notification '{"notification_type":"idle_prompt"}'
is "idle_prompt on a done pane leaves it done" "$(wst "$W_API")" done
T set-option -up -t "$P_API" @agent_pane_state; "$AS" seen >/dev/null 2>&1; T set-option -uw -t "$W_API" @agent_state
hook "$P_API" Notification '{"notification_type":"idle_prompt"}'
is "idle_prompt on an idle pane stays idle" "$(wst "$W_API")" ""
hook "$P_API" PreToolUse '{"tool_name":"Bash"}'
hook "$P_API" Notification '{"notification_type":"idle_prompt"}'
is "idle_prompt rescues an interrupted turn -> done" "$(wst "$W_API")" done

printf '{"notification_type":"idle_prompt"}' | TMUX_PANE=$P_API "$AS" hook Notification; rc=$?
is "idle_prompt on a pane with nothing to rescue exits 0" "$rc" 0

finish
