#!/bin/sh
# The entry file: badge and summary formats, key bindings, hooks, idempotency.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

case $(T show-option -gv window-status-format) in
  *@agent_icon*) got=appended ;;
  *) got=$(T show-option -gv window-status-format) ;;
esac
is "badge appended to window-status-format" "$got" appended
case $(T show-option -gv status-right) in
  "#{@agent_summary}"*) got=prepended ;;
  *) got=$(T show-option -gv status-right) ;;
esac
is "summary prepended to status-right" "$got" prepended
is "next key bound"      "$(T list-keys -T prefix | grep -c 'agent-signal next')" 1
is "seen hook installed" "$(T show-hooks -g | grep -c 'after-select-window\[91\]')" 1

sh "$ROOT/agent-signal.tmux"
is "sourcing the entry file twice appends the badge once (2 mentions per badge)" "$(T show-option -gv window-status-format | grep -o agent_icon | wc -l | tr -d ' ')" 2
is "sourcing twice prepends the summary once"                                    "$(T show-option -gv status-right | grep -o agent_summary | wc -l | tr -d ' ')" 1

is "the command path is published for other agents to find" "$(T show-option -gv @agent_signal_command)" "$AS"

finish
