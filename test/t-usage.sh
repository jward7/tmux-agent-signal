#!/bin/sh
# help, version and the error paths of the command dispatcher.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

out=$("$AS" help); rc=$?
is "help exits 0"                             "$rc" 0
is "help prints the usage block"              "$(printf '%s\n' "$out" | grep -c 'agent-signal hook')" 1
is "version prints the version"               "$(TMUX='' "$AS" version)" "0.2.1"
is "help works outside tmux"                  "$(TMUX='' "$AS" --help | grep -c Usage)" 1
is "unknown command exits 1 with a message"   "$("$AS" bogus 2>&1 >/dev/null | head -1)" "agent-signal: unknown command 'bogus'"
is "hold without a mode explains itself"      "$("$AS" hold 2>&1 | head -1)" "agent-signal hold: wait, park or clear"

finish
