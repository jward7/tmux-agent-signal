#!/bin/sh
# A hook killed while holding its window's lock leaves the lock directory
# behind. The next hook for that window waits ~2s, then reclaims it.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

LOCK=$("$AS" lock-path "$W_API")
mkdir "$LOCK"
hook "$P_API" PermissionRequest
is "a stale lock is reclaimed and the state is set"   "$(wst "$W_API")" blocked
is "the reclaimed lock is released afterwards"        "$([ -d "$LOCK" ] && echo left || echo gone)" gone
is "no lock directories left behind"                  "$(leftovers 'agent-signal.*.lock.*')" 0

finish
