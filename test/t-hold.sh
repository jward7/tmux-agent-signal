#!/bin/sh
# Triage: "wait" until something changes, "park" until you come back.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

hook "$P_WEB2" Stop                  # web: done, and nobody is looking, so the flag stays
"$AS" hold wait "$W_WEB"
is "wait icon"                       "$(wicon "$W_WEB")" "…"
hook "$P_WEB2" UserPromptSubmit
is "new event clears wait"           "$(whold "$W_WEB")" ""
"$AS" hold park "$W_WEB"
is "park set"                        "$(whold "$W_WEB")" park
hook "$P_WEB2" PermissionRequest
is "blocked shows through park"      "$(wicon "$W_WEB")" "!"
"$AS" hold park "$W_WEB"
is "park toggles off"                "$(whold "$W_WEB")" ""

# A hold on a window with no state at all (the tab-separated read used to
# drop the empty first field and take the hold for the previous state).
"$AS" hold park "$W_API"
is "park on an idle window shows p"  "$(wicon "$W_API")" p
hook "$P_API" UserPromptSubmit
is "park persists through working"   "$(wicon "$W_API")" p
is "and the hold is still recorded"  "$(whold "$W_API")" park
hook "$P_API" PreToolUse '{"tool_name":"AskUserQuestion"}'
is "ask shows through park"          "$(wicon "$W_API")" "?"
"$AS" hold wait "$W_API"
is "wait replaces park"              "$(whold "$W_API")" wait
"$AS" hold wait "$W_API"
is "wait toggles off"                "$(whold "$W_API")" ""
"$AS" hold clear "$W_API"
is "clear on a clear window is a no-op" "$(whold "$W_API")" ""

finish
