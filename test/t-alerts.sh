#!/bin/sh
# The alert command: fires on transitions, with the state in the environment.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

hook "$P_WEB2" Stop; hook "$P_API" UserPromptSubmit
is "a refresh leaves no temp files"  "$(leftovers 'agent-signal.[0-9]*')" 0
hook "$P_API" SessionEnd; hook "$P_WEB2" SessionEnd
is "all state cleared"               "$(T list-panes -a -F '#{@agent_pane_state}' | tr -d '\n')" ""

LOG="$TMPDIR/alerts.log"
# shellcheck disable=SC2016  # the $vars are meant for the helper script, not this shell
printf '%s\n' '#!/bin/sh' 'printf "%s<%s %s\\n" "$AGENT_SIGNAL_STATE" "$AGENT_SIGNAL_PREV" "$1" >> "$2"' > "$TMPDIR/alert.sh"
T set-option -g @agent_signal_alert_command "sh '$TMPDIR/alert.sh' '#{window_name}' '$LOG'"
hook "$P_API" UserPromptSubmit; hook "$P_API" PermissionRequest; hook "$P_API" PermissionRequest; hook "$P_API" Stop
i=0; while [ "$(wc -l < "$LOG" 2>/dev/null | tr -d ' ')" != 2 ] && [ $i -lt 40 ]; do sleep 0.05; i=$((i + 1)); done
is "alert command fires on transitions only, with env and expanded formats" "$(cat "$LOG")" "blocked<working api
done<blocked api"
T set-option -g @agent_signal_alert_states blocked
: > "$LOG"; hook "$P_API" PermissionRequest; hook "$P_API" Stop; sleep 0.3
is "alert states limit which transitions fire"       "$(cat "$LOG")" "blocked<done api"
T set-option -g @agent_signal_alert_command "printf '%s\\n' 100% >> '$LOG'"
: > "$LOG"; hook "$P_API" PermissionRequest; sleep 0.3
is "a percent sign in the alert command survives tmux's strftime" "$(cat "$LOG")" "100%"
T set-option -gu @agent_signal_alert_command; T set-option -gu @agent_signal_alert_states; hook "$P_API" SessionEnd

finish
