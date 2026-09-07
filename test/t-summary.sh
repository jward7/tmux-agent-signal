#!/bin/sh
# The status-right summary: one glyph per agent pane, and the state it clears to.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

hook "$P_WEB2" Stop              # a second agent pane, so the summary has two entries
hook "$P_API" UserPromptSubmit
case $(gsum) in
  *"✳$(T display -p -t "$W_API" '#{window_index}')"*) got=shown ;;
  *) got=$(gsum) ;;
esac
is "summary shows glyph+window index"     "$got" shown
is "summary entries are space separated"  "$(gsum | tr -cd ' ' | wc -c | tr -d ' ')" 2
is "summary leaves no temp files"         "$(leftovers 'agent-signal.[0-9]*')" 0

ascii on; hook "$P_API" Stop
is "ascii preset uses + for done"    "$(wicon "$W_API")" "+"
ascii off
T set-option -g @agent_signal_working BROKEN
is "a malformed style option is reported, not passed to tmux" "$(hook "$P_API" UserPromptSubmit 2>&1 | grep -c 'must be')" 1
T set-option -gu @agent_signal_working

hook "$P_API" SessionEnd; hook "$P_WEB2" SessionEnd
is "all state cleared"               "$(T list-panes -a -F '#{@agent_pane_state}' | tr -d '\n')" ""
is "summary cleared"                 "$(gsum)" ""

LOG="$TMPDIR/alerts.log"
T set-option -g @agent_signal_alert_command "printf '%s<%s #{window_name}\\n' \"\$AGENT_SIGNAL_STATE\" \"\$AGENT_SIGNAL_PREV\" >> '$LOG'"
hook "$P_API" UserPromptSubmit; hook "$P_API" PermissionRequest; hook "$P_API" PermissionRequest; hook "$P_API" Stop
i=0; while [ "$(wc -l < "$LOG" 2>/dev/null | tr -d ' ')" != 2 ] && [ $i -lt 40 ]; do sleep 0.05; i=$((i + 1)); done
is "alert command fires on transitions only, with env and expanded formats" "$(cat "$LOG")" "blocked<working api
done<blocked api"
T set-option -g @agent_signal_alert_states blocked
: > "$LOG"; hook "$P_API" PermissionRequest; hook "$P_API" Stop; sleep 0.3
is "alert states limit which transitions fire"       "$(cat "$LOG")" "blocked<done api"
T set-option -gu @agent_signal_alert_command; T set-option -gu @agent_signal_alert_states; hook "$P_API" SessionEnd

finish
