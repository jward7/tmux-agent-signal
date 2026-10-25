#!/bin/sh
# A key binding the user already has is never clobbered; ours is rebound freely.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

"$AS" uninstall >/dev/null
T bind-key N previous-window
sh "$ROOT/agent-signal.tmux" 2>/dev/null
is "an existing prefix+N binding is left alone"  "$(T list-keys -T prefix | awk '$4 == "N"' | grep -c previous-window)" 1
is "the other three keys are still bound"        "$(T list-keys -T prefix | grep -cE 'agent-signal (hold|next)|switcher')" 3
T unbind-key N; sh "$ROOT/agent-signal.tmux"
is "reloading rebinds our own key without complaint" "$(T list-keys -T prefix | awk '$4 == "N"' | grep -c 'agent-signal next')" 1

# "" switches a binding off (an empty option used to read as the default).
"$AS" uninstall >/dev/null
T set-option -g @agent_signal_key_next ''
sh "$ROOT/agent-signal.tmux"
is "key option set to \"\" leaves the key unbound" "$(T list-keys -T prefix | awk '$4 == "N"' | wc -l | tr -d ' ')" 0
is "check reports the binding as switched off"   "$("$AS" check | grep -c 'next binding switched off')" 1
T set-option -gu @agent_signal_key_next

# A custom key is bound, reported and removed.
"$AS" uninstall >/dev/null
T set-option -g @agent_signal_key_next Y
sh "$ROOT/agent-signal.tmux"
is "custom key is bound"             "$(T list-keys -T prefix | awk '$4 == "Y"' | grep -c 'agent-signal next')" 1
is "check knows the custom key"      "$("$AS" check | grep -c 'prefix+Y -> next')" 1
"$AS" uninstall >/dev/null
is "uninstall removes the custom key" "$(T list-keys -T prefix | awk '$4 == "Y"' | wc -l | tr -d ' ')" 0
T set-option -gu @agent_signal_key_next; sh "$ROOT/agent-signal.tmux"

finish
