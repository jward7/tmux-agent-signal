#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# Without jq on PATH the sed/grep fallbacks must read the same JSON.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

NOJQ=$(mktemp -d); for b in sh cat tmux awk sed grep tr head cut sort ls mkdir rmdir sleep id dirname; do ln -s "$(command -v "$b")" "$NOJQ/$b"; done
nojq() { printf '%s' "$3" | PATH=$NOJQ TMUX_PANE=$1 "$AS" hook "$2"; }
nojq "$P_API" PreToolUse '{ "tool_name" : "AskUserQuestion" }'
is "sed fallback reads spaced JSON -> ask"        "$(wst "$W_API")" ask
nojq "$P_API" Stop '{"background_tasks": [ {"id": "x"} ]}'
is "sed fallback sees a non-empty task array"     "$(wst "$W_API")" working
nojq "$P_API" Stop '{"background_tasks": []}'
is "sed fallback sees an empty task array -> done" "$(wst "$W_API")" done
hook "$P_API" SessionEnd; rm -rf "$NOJQ"

finish
