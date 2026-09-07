#!/bin/sh
# A key binding the user already has is never clobbered; ours is rebound freely.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

"$AS" uninstall >/dev/null
T bind-key N previous-window
sh "$ROOT/agent-signal.tmux" 2>/dev/null
is "an existing prefix+N binding is left alone"  "$(T list-keys -T prefix | awk '$4 == "N"' | grep -c previous-window)" 1
is "the other three keys are still bound"        "$(T list-keys -T prefix | grep -cE 'agent-signal (hold|next)|switcher')" 3
T unbind-key N; sh "$ROOT/agent-signal.tmux"
is "reloading rebinds our own key without complaint" "$(T list-keys -T prefix | awk '$4 == "N"' | grep -c 'agent-signal next')" 1

finish
