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

finish
