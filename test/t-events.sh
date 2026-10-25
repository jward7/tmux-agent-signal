#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# The rest of the hook mapping (StopFailure, the other Notification types,
# SessionStart sources, unknown events) and the edges of `set`, `clear` and
# `sync`: missing arguments, bad states, missing panes, no tmux, disabled.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

# SessionStart also syncs Claude's registry from $HOME: keep it off the real one.
EMPTY_HOME="$TMPDIR/home"; mkdir -p "$EMPTY_HOME"
start() { # start <pane> <source>
  printf '{"source":"%s"}' "$2" | HOME=$EMPTY_HOME TMUX_PANE=$1 "$AS" hook SessionStart
}
kind() { T display -p -t "$1" '#{@agent_kind}'; }

# --- StopFailure -------------------------------------------------------------
hook "$P_API" UserPromptSubmit
hook "$P_API" StopFailure '{"background_tasks":[{"id":"x"}]}'
is "StopFailure with a background task -> working" "$(pst "$P_API")" working
hook "$P_API" StopFailure '{"error":"rate_limit"}'
is "StopFailure with no background tasks -> done"  "$(pst "$P_API")" done

# --- Notification ------------------------------------------------------------
hook "$P_API" UserPromptSubmit
hook "$P_API" Notification '{"notification_type":"elicitation_dialog"}'
is "Notification elicitation_dialog -> ask"      "$(pst "$P_API")" ask
hook "$P_API" UserPromptSubmit
hook "$P_API" Notification '{"notification_type":"agent_needs_input"}'
is "Notification agent_needs_input -> ask"       "$(pst "$P_API")" ask
hook "$P_API" UserPromptSubmit
hook "$P_API" Notification '{"notification_type":"auth_success"}'; rc=$?
is "Notification of an unknown type exits 0"     "$rc" 0
is "Notification of an unknown type changes nothing" "$(pst "$P_API")" working
hook "$P_API" Notification; rc=$?
is "Notification with no type changes nothing"   "$rc $(pst "$P_API")" "0 working"

# --- SessionStart sources ----------------------------------------------------
for src in startup clear fork; do
  hook "$P_API" UserPromptSubmit
  start "$P_API" "$src"
  is "SessionStart $src takes a working pane to idle" "$(pst "$P_API") $(wst "$W_API")" " "
done

# --- unknown event -----------------------------------------------------------
hook "$P_API" UserPromptSubmit
out=$(printf '{}' | TMUX_PANE=$P_API "$AS" hook SubagentStop 2>&1); rc=$?
is "an unknown hook event exits 0 silently"      "$rc [$out]" "0 []"
is "an unknown hook event changes nothing"       "$(pst "$P_API") $(kind "$P_API")" "working claude"

# --- set ---------------------------------------------------------------------
TMUX_PANE=$P_API "$AS" set idle
is "set idle clears the pane state"              "$(pst "$P_API")" ""
is "set idle clears the window state"            "$(wst "$W_API")" ""
is "set idle still marks the pane as an agent"   "$(kind "$P_API")" agent

hook "$P_API" UserPromptSubmit
LOCK=$("$AS" lock-path "$W_API")
err=$(TMUX_PANE=$P_API "$AS" set bogus 2>&1 >/dev/null); rc=$?
is "set bogus exits 1"                           "$rc" 1
is "set bogus says the state is unknown"         "$(printf '%s\n' "$err" | grep -c 'unknown state')" 1
is "set bogus leaves the pane as it was"         "$(pst "$P_API")" working
is "set bogus leaves no lock directory behind"   "$([ -e "$LOCK" ] && echo present || echo absent)" absent

err=$(TMUX_PANE=$P_API "$AS" set 2>&1 >/dev/null); rc=$?
is "set with no state exits 1"                   "$rc" 1
is "set with no state asks which state"          "$(printf '%s\n' "$err" | grep -c 'which state')" 1
err=$(printf '{}' | TMUX_PANE=$P_API "$AS" hook 2>&1 >/dev/null); rc=$?
is "hook with no event exits 1"                  "$rc" 1
is "hook with no event asks which event"         "$(printf '%s\n' "$err" | grep -c 'which event')" 1

before=$(T list-panes -a -F '#{pane_id}=#{@agent_pane_state}' | tr '\n' ' ')
"$AS" set working %999 >/dev/null 2>&1; rc=$?
is "set on a pane that does not exist exits 0"   "$rc" 0
is "set on a pane that does not exist changes nothing" "$(T list-panes -a -F '#{pane_id}=#{@agent_pane_state}' | tr '\n' ' ')" "$before"

out=$(TMUX='' TMUX_PANE=$P_WEB "$AS" set working 2>&1); rc=$?
is "set outside tmux exits 0 silently"           "$rc [$out]" "0 []"
is "set outside tmux touches nothing"            "$(pst "$P_WEB")" ""

TMUX_PANE=$P_API "$AS" set blocked "$P_WEB"
is "an explicit pane argument beats TMUX_PANE"   "$(pst "$P_WEB")" blocked
is "the TMUX_PANE pane is left alone"            "$(pst "$P_API")" working
"$AS" clear "$P_WEB"

# --- AGENT_SIGNAL_DISABLE on clear and sync ----------------------------------
AGENT_SIGNAL_DISABLE=1 TMUX_PANE=$P_API "$AS" clear; rc=$?
is "AGENT_SIGNAL_DISABLE=1 clear exits 0"        "$rc" 0
is "AGENT_SIGNAL_DISABLE=1 clear changes nothing" "$(pst "$P_API") $(kind "$P_API")" "working claude"
REG="$TMPDIR/reg"; mkdir -p "$REG/.claude/sessions"
printf '{"tmux":"main:%s.%s","name":"nested"}\n' "$W_API" "$P_API" > "$REG/.claude/sessions/a.json"
AGENT_SIGNAL_DISABLE=1 HOME=$REG "$AS" sync; rc=$?
is "AGENT_SIGNAL_DISABLE=1 sync exits 0"         "$rc" 0
is "AGENT_SIGNAL_DISABLE=1 sync names nothing"   "$(T display -p -t "$P_API" '#{@agent_name}')" ""
HOME=$REG "$AS" sync
is "the same sync without it does name the pane" "$(T display -p -t "$P_API" '#{@agent_name}')" nested

# --- no arguments ------------------------------------------------------------
out=$("$AS" 2>/dev/null); rc=$?
err=$("$AS" 2>&1 >/dev/null)
is "no arguments exits 1"                        "$rc" 1
is "no arguments prints nothing on stdout"       "$out" ""
is "no arguments prints the usage on stderr"     "$(printf '%s\n' "$err" | grep -c 'agent-signal set <state>')" 1

finish
