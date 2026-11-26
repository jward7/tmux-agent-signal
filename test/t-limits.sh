#!/bin/sh
# shellcheck disable=SC1010  # bare "done" here is a state name, not a loop keyword
# The opt-in usage meter: Claude's statusLine JSON and Codex's rollout logs
# recorded as @agent_limit_* options, and @agent_limits built from them.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

NOW=1800000000          # every run of the script is told this is the time
R5=$((NOW + 9000))      # a 5-hour window with half of it left
R7=$((NOW + 300000))    # a weekly window with about half of it left
NOJQ=$(mktemp -d); for b in sh cat tmux awk sed grep tr head tail find cut sort ls mkdir rmdir sleep id dirname date; do ln -s "$(command -v "$b")" "$NOJQ/$b"; done
RUNPATH=$PATH           # swapped for $NOJQ to run the same cases without jq

g()     { T show-option -gqv "$1"; }
count() { T show-options -g | grep -c '^@agent_limit_'; }
wipe()  { for o in $(T show-options -g | sed -n 's/^\(@agent_limit[a-z0-9_]*\) .*/\1/p'); do T set-option -gu "$o"; done; }
sl()    { printf '%s\n' "$1" | PATH=$RUNPATH AGENT_SIGNAL_NOW=$NOW "$AS" statusline; }   # sl <payload>
put()   { T set-option -g "@agent_limit_$1" "$2"; }                                       # put <agent_window_field> <value>
recompute() { AGENT_SIGNAL_NOW=$NOW "$AS" limits; g @agent_limits; }

# What Claude Code 2.1 pipes to a statusLine command, cut down: the windows sit
# under rate_limits, and context_window has a used_percentage of its own.
payload() { # payload <rate_limits member, or nothing>
  printf '{"session_id":"abc","cwd":"/x","model":{"id":"claude-opus-5-5","display_name":"Opus"},"context_window":{"context_window_size":200000,"used_percentage":8,"remaining_percentage":92},"exceeds_200k_tokens":false%s,"vim":{"mode":"INSERT"}}' "${1:+,$1}"
}
FULL=$(payload "\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5,\"resets_at\":$R5},\"seven_day\":{\"used_percentage\":41.2,\"resets_at\":$R7}}")
WEEKLY=$(payload "\"rate_limits\":{\"seven_day\":{\"used_percentage\":36,\"resets_at\":$R7}}")
five() { payload "\"rate_limits\":{\"five_hour\":{\"used_percentage\":$1,\"resets_at\":$2}}"; }   # five <used> <reset>

# Codex's rollout log: one JSON object per line, token_count events carrying
# the windows as primary and secondary.
CX=$TMPDIR/codex; DAY=$CX/sessions/2026/11/26
tc()  { printf '{"timestamp":"2026-11-26T01:02:03.456Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1,"output_tokens":2,"total_tokens":3},"model_context_window":272000},"rate_limits":%s}}\n' "$1"; }
cw()  { printf '{"used_percent":%s,"window_minutes":%s,"resets_at":%s}' "$1" "$2" "$3"; }   # cw <used> <minutes> <reset>
rl()  { printf '{"limit_id":"codex","primary":%s,"secondary":%s,"credits":{"has_credits":false,"unlimited":false,"balance":null},"plan_type":"plus"}' "$1" "$2"; }
other() { printf '{"timestamp":"2026-11-26T01:02:04.000Z","type":"event_msg","payload":{"type":"agent_message","message":"primary and secondary {braces}"}}\n'; }
rollout() { rm -rf "$CX"; mkdir -p "$DAY"; cat > "$DAY/rollout-2026-11-26T01-02-03-0199a0b1-$1.jsonl"; }   # rollout <name> < lines
codex_done() { AGENT_KIND=codex TMUX_PANE=$P_API CODEX_HOME=$CX AGENT_SIGNAL_NOW=$NOW PATH=$RUNPATH "$AS" set done; }

# --- off by default ----------------------------------------------------------
{ tc "$(rl "$(cw 12 300 "$R5")" "$(cw 30 10080 "$R7")")"; } | rollout a
out=$(sl "$FULL"); rc=$?
is "off: statusline exits 0 and prints nothing"     "$rc:$out" "0:"
codex_done
hook "$P_API" UserPromptSubmit
is "off: nothing is recorded by statusline, a Codex turn end or a Claude hook" "$(count)" 0
is "off: @agent_limits stays unset"                 "$(T show-options -g | grep -c '^@agent_limits')" 0
printf '%s\n' "$FULL" > "$TMPDIR/in"
out=$("$AS" statusline "cat > '$TMPDIR/got'; echo one; echo two; exit 3" < "$TMPDIR/in"); rc=$?
is "off: the previous status line still runs"       "$rc:$(printf '%s' "$out" | tr '\n' ' ')" "3:one two"
is "check says the meter is off"                    "$("$AS" check | grep -c 'ok   usage meter switched off')" 1

T set-option -g @agent_signal_limits on

# --- Claude payloads, with and without jq ------------------------------------
claude_cases() { # claude_cases <label>
  wipe
  out=$(sl "$FULL"); rc=$?
  is "$1: a full payload exits 0 and prints nothing" "$rc:$out" "0:"
  is "$1: 5h used is an integer (23.5 -> 23)"        "$(g @agent_limit_claude_5h_used)" 23
  is "$1: 5h reset is recorded"                      "$(g @agent_limit_claude_5h_reset)" "$R5"
  is "$1: 7d used (41.2 -> 41)"                      "$(g @agent_limit_claude_7d_used)" 41
  is "$1: 7d reset is recorded"                      "$(g @agent_limit_claude_7d_reset)" "$R7"
  is "$1: the time of recording is kept"             "$(g @agent_limit_claude_at)" "$NOW"
  is "$1: @agent_limits shows what is left, weekly too when tighter" "$(g @agent_limits)" "C 77% w59%"
  is "$1: context_window.used_percentage is not a limit" "$(count)" 5

  # An idle session re-reports what it last saw: it must not undo newer news.
  sl "$(five 10 "$R5")"
  is "$1: the same window never goes down"           "$(g @agent_limit_claude_5h_used)" 23
  sl "$(five 99 $((R5 - 18000)))"
  is "$1: an earlier window does not replace a later one" "$(g @agent_limit_claude_5h_used):$(g @agent_limit_claude_5h_reset)" "23:$R5"
  sl "$(five 5 $((R5 + 18000)))"
  is "$1: a later window replaces it, even with less used" "$(g @agent_limit_claude_5h_used):$(g @agent_limit_claude_5h_reset)" "5:$((R5 + 18000))"

  wipe; sl "$WEEKLY"
  is "$1: seven_day alone records only the weekly window" "$(g @agent_limit_claude_7d_used):$(g @agent_limit_claude_5h_used):$(count)" "36::3"
  is "$1: and the weekly figure stands alone"        "$(g @agent_limits)" "C w64%"

  wipe; sl "$(payload)"; sl "$(payload '"rate_limits":null')"; sl "$(payload '"rate_limits":{}')"
  is "$1: no rate_limits records nothing"            "$(count)" 0
  out=$(sl '{"rate_limits":{"five_hour":{"used_percentage":55,"resets_at":'); rc=$?
  is "$1: truncated JSON exits 0 and prints nothing" "$rc:$out" "0:"
  sl 'not json at all'; sl ''
  is "$1: malformed JSON records nothing"            "$(count)" 0
  is "$1: with nothing recorded @agent_limits is unset" "$(T show-options -g | grep -c '^@agent_limits')" 0

  sl "$(printf '{\n  "rate_limits" : {\n    "five_hour" : {\n      "resets_at" : %s,\n      "used_percentage" : 99.9\n    }\n  }\n}' "$R5")"
  is "$1: pretty-printed JSON, 99.9 stays 99"        "$(g @agent_limit_claude_5h_used):$(g @agent_limit_claude_5h_reset)" "99:$R5"
  wipe; sl "$(five 0.4 "$R5")"
  is "$1: 0.4 is 0"                                  "$(g @agent_limit_claude_5h_used)" 0
  wipe; sl "$(five 104.5 "$R5")"
  is "$1: over 100 is held at 100"                   "$(g @agent_limit_claude_5h_used)" 100
}
claude_cases "jq"
RUNPATH=$NOJQ; claude_cases "no jq"; RUNPATH=$PATH

# --- chaining to the previous status line ------------------------------------
wipe
out=$("$AS" statusline "cat > '$TMPDIR/got'; echo one; echo two; exit 3" < "$TMPDIR/in"); rc=$?
is "chain: the previous command gets the identical stdin" "$(cmp -s "$TMPDIR/in" "$TMPDIR/got" && echo same)" same
is "chain: its output is printed"                   "$(printf '%s' "$out" | tr '\n' ' ')" "one two"
is "chain: its exit status is kept"                 "$rc" 3
is "chain: and the limits were still recorded"      "$(g @agent_limit_claude_5h_used)" 23
T set-option -g @agent_signal_statusline_next 'echo from-option'
is "chain: @agent_signal_statusline_next names the command" "$("$AS" statusline < "$TMPDIR/in")" from-option
is "chain: an argument wins over the option"        "$("$AS" statusline 'echo from-arg' < "$TMPDIR/in")" from-arg
T set-option -gu @agent_signal_statusline_next
is "chain: outside tmux the previous command still runs" "$(TMUX='' "$AS" statusline 'cat' < "$TMPDIR/in")" "$FULL"

# --- Codex rollout logs ------------------------------------------------------
codex_cases() { # codex_cases <label>
  wipe
  { tc "$(rl "$(cw 12.0 300 "$R5")" "$(cw 30.5 10080 "$R7")")"; other
    tc "$(rl "$(cw 15.0 300 "$R5")" "$(cw 31.0 10080 "$R7")")"; other; tc null; other; } | rollout a
  codex_done
  is "$1: the newest token_count wins"               "$(g @agent_limit_codex_5h_used):$(g @agent_limit_codex_7d_used)" "15:31"
  is "$1: resets and the recording time are kept"    "$(g @agent_limit_codex_5h_reset):$(g @agent_limit_codex_7d_reset):$(g @agent_limit_codex_at)" "$R5:$R7:$NOW"
  is "$1: the turn end still marks the pane done"    "$(pst "$P_API")" done
  is "$1: @agent_limits carries Codex as X"          "$(g @agent_limits)" "X 85% w69%"

  wipe; { tc "$(rl "$(cw 44 10080 "$R7")" null)"; } | rollout a; codex_done
  is "$1: weekly-only data lands in 7d, whatever its position" "$(g @agent_limit_codex_7d_used):$(g @agent_limit_codex_5h_used)" "44:"
  wipe; { tc "$(rl "$(cw 61 10080 "$R7")" "$(cw 7 300 "$R5")")"; } | rollout a; codex_done
  is "$1: windows are mapped by window_minutes, not position" "$(g @agent_limit_codex_5h_used):$(g @agent_limit_codex_7d_used)" "7:61"
  wipe; { tc "$(rl "$(cw 50 43200 "$R7")" null)"; } | rollout a; codex_done
  is "$1: a monthly window is not recorded"          "$(count)" 0
  wipe; { tc "$(rl '{"used_percent":20,"window_minutes":300,"resets_in_seconds":600}' '{"used_percent":3.0,"window_minutes":10080}')"; } | rollout a; codex_done
  is "$1: resets_in_seconds counts from now"         "$(g @agent_limit_codex_5h_reset)" "$((NOW + 600))"
  is "$1: with neither reset field no reset is stored" "$(g @agent_limit_codex_7d_used):$(T show-options -g | grep -c '^@agent_limit_codex_7d_reset')" "3:0"

  # Two logs: the one written last is read, the older one never.
  wipe; { tc "$(rl "$(cw 90 300 $((R5 + 999)))" null)"; } | rollout old; sleep 1.1
  { tc "$(rl "$(cw 33 300 "$R5")" null)"; } > "$DAY/rollout-2026-11-26T02-00-00-0199a0b1-new.jsonl"; codex_done
  is "$1: the newest rollout file is the one read"   "$(g @agent_limit_codex_5h_used)" 33

  wipe; { other; other; } | rollout a; codex_done
  is "$1: a log with no rate_limits records nothing" "$(count)" 0
  rm -rf "$CX"; err=$(codex_done 2>&1); rc=$?
  is "$1: a missing sessions directory is quiet"     "$rc:$err:$(count)" "0::0"
}
codex_cases "jq"
RUNPATH=$NOJQ; codex_cases "no jq"; RUNPATH=$PATH
wipe; { tc "$(rl "$(cw 15 300 "$R5")" null)"; } | rollout a
AGENT_KIND=codex TMUX_PANE=$P_API CODEX_HOME=$CX AGENT_SIGNAL_NOW=$NOW "$AS" set working
is "codex: only a turn end reads the log"            "$(count)" 0

# --- pace: 2h15m left of a 5-hour window means 45% should be left -----------
wipe; put claude_at "$NOW"; put claude_5h_reset $((NOW + 8100))
put claude_5h_used 70
is "pace: 30% left against 45% expected is over pace (orange)" "$(recompute)" "C #[fg=colour208]30%#[default]"
put claude_5h_used 60
is "pace: 40% left is within the 10 points"          "$(recompute)" "C 40%"
put claude_5h_used 70; T set-option -g @agent_signal_limits_pace 20
is "pace: a wider threshold tolerates 30%"           "$(recompute)" "C 30%"
T set-option -g @agent_signal_limits_pace 0; put claude_5h_used 89
is "pace: 0 never colours for pace"                  "$(recompute)" "C 11%"
put claude_5h_used 90
is "90% used is orange whatever the pace"            "$(recompute)" "C #[fg=colour208]10%#[default]"
put claude_5h_used 100
is "100% used is red"                                "$(recompute)" "C #[fg=red]0%#[default]"
T set-option -gu @agent_signal_limits_pace
T set-option -g @agent_signal_limits_show used; put claude_5h_used 70
is "show used: the figure is what has been used"     "$(recompute)" "C #[fg=colour208]70%#[default]"
T set-option -gu @agent_signal_limits_show

# The weekly figure joins only when it is the tighter one, or flagged.
put claude_5h_used 38; put claude_7d_reset $((NOW + 302400))
put claude_7d_used 20
is "weekly with more left than the 5h window is not shown" "$(recompute)" "C 62%"
put claude_7d_used 45
is "weekly with less left is shown beside it"        "$(recompute)" "C 62% w55%"
put claude_5h_used 80; put claude_5h_reset $((NOW + 3600)); put claude_7d_used 75; put claude_7d_reset $((NOW + 518400))
is "weekly over pace is shown even with more left"   "$(recompute)" "C 20% w#[fg=colour208]25%#[default]"
put claude_5h_used 38; put claude_5h_reset $((NOW + 8100)); put claude_7d_used 20
put codex_at "$NOW"; put codex_5h_used 60; put codex_5h_reset $((NOW + 9000))
is "two agents share the one option"                 "$(recompute)" "C 62% X 40%"
is "the status line reads it as a format"            "$(T display -p '#{@agent_limits}')" "C 62% X 40%"

# Any agent event recomputes it: time has passed, and the pace with it.
put claude_5h_used 70
AGENT_SIGNAL_NOW=$NOW; export AGENT_SIGNAL_NOW; hook "$P_API" UserPromptSubmit; unset AGENT_SIGNAL_NOW
is "a Claude hook rebuilds @agent_limits"            "$(g @agent_limits)" "C #[fg=colour208]30%#[default] X 40%"

# --- staleness ---------------------------------------------------------------
put claude_at $((NOW - 21601))
is "an agent not heard from for six hours is dimmed, colour and all" "$(recompute)" "#[fg=colour245]C 30%#[default] X 40%"
put claude_at "$NOW"; put claude_5h_reset "$NOW"; put claude_7d_reset $((NOW + 302400)); put claude_7d_used 20
is "a window whose reset has passed is dropped"      "$(recompute)" "C w80% X 40%"
put claude_7d_reset $((NOW - 1)); put codex_5h_reset $((NOW - 1))
is "with every window past its reset the option is unset" "$(recompute):$(T show-options -g | grep -c '^@agent_limits')" ":0"
T set-option -gu @agent_limit_codex_5h_reset
is "a window with no reset is shown, without a pace" "$(recompute)" "X 40%"

# --- check -------------------------------------------------------------------
out=$("$AS" check); rc=$?
is "check exits 0 with the meter on"                 "$rc" 0
is "check shows the meter without its styles"        "$(printf '%s\n' "$out" | grep -c 'ok   usage meter on: X 40%$')" 1
is "check warns that Claude's statusLine is not wired" "$(printf '%s\n' "$out" | grep -c 'warn Claude Code statusLine does not run agent-signal statusline')" 1
wipe; "$AS" limits
is "check says when nothing has been recorded"       "$("$AS" check | grep -c 'usage meter on: nothing recorded yet')" 1

# --- install-claude-statusline and uninstall ---------------------------------
mkdir -p "$HOME/.claude"; S="$HOME/.claude/settings.json"
ORIG='{"type":"command","command":"printf '"'"'%s\\n'"'"' \"it'"'"'s mine\"; cat >/dev/null","padding":2}'
printf '{"model":"x","statusLine":%s,"hooks":{}}\n' "$ORIG" > "$S"
out=$("$AS" install-claude-statusline); rc=$?
is "install exits 0 and says what it did"            "$rc:$(printf '%s\n' "$out" | grep -c 'statusLine set in')" "0:1"
is "install points statusLine at the quoted script"  "$(jq -r '.statusLine.command' "$S" | cut -c1-$((${#AS} + 13)))" "\"$AS\" statusline"
is "install keeps the other statusLine fields"       "$(jq -c '[.statusLine.type, .statusLine.padding]' "$S")" '["command",2]'
is "install keeps unrelated settings"                "$(jq -c '[.model, .hooks]' "$S")" '["x",{}]'
is "the installed command still runs the user's status line" "$(sh -c "$(jq -r '.statusLine.command' "$S")" < "$TMPDIR/in")" "it's mine"
is "and records the limits on the way"               "$(g @agent_limit_claude_5h_used)" 23
is "check sees the statusLine wired"                 "$("$AS" check | grep -c 'ok   Claude Code statusLine runs agent-signal statusline')" 1
first=$(jq -c '.statusLine' "$S")
"$AS" install-claude-statusline >/dev/null
is "re-running install changes nothing"              "$(jq -c '.statusLine' "$S")" "$first"
is "and the original is still the one kept"          "$(jq -c . "$S.statusline-agent-signal")" "$ORIG"
is "install leaves no temp files"                    "$(find "$HOME/.claude" -name 'settings.json.??????' | wc -l | tr -d ' ')" 0
"$AS" uninstall >/dev/null
is "uninstall restores the original statusLine exactly" "$(jq -c '.statusLine' "$S")" "$ORIG"
is "uninstall keeps unrelated settings"              "$(jq -c '[.model, .hooks]' "$S")" '["x",{}]'
is "uninstall removes the kept copy and leaves no temp files" "$(find "$HOME/.claude" -type f | wc -l | tr -d ' ')" 1
is "uninstall unsets the recorded limits and @agent_limits" "$(T show-options -g | grep -c '^@agent_limit')" 0
"$AS" uninstall >/dev/null
is "a second uninstall leaves the statusLine alone"  "$(jq -c '.statusLine' "$S")" "$ORIG"

# No statusLine to begin with: one is added, and uninstall takes it away again.
printf '{"model":"x"}\n' > "$S"
"$AS" install-claude-statusline >/dev/null
is "with no statusLine, install adds a bare one"     "$(jq -c '.statusLine' "$S")" "{\"type\":\"command\",\"command\":\"\\\"$AS\\\" statusline\"}"
"$AS" uninstall >/dev/null
is "and uninstall removes it again"                  "$(jq -c . "$S")" '{"model":"x"}'
# A statusLine the user has since replaced is theirs: uninstall keeps it.
"$AS" install-claude-statusline >/dev/null
jq '.statusLine.command = "echo newer"' "$S" > "$S.new" && mv "$S.new" "$S"
"$AS" uninstall >/dev/null
is "uninstall leaves a statusLine that is no longer ours" "$(jq -r '.statusLine.command' "$S")" "echo newer"

rm -rf "$HOME/.claude"
"$AS" install-claude-statusline >/dev/null; rc=$?
is "install with no settings.json creates one"       "$rc:$(jq -r '.statusLine.command' "$S")" "0:\"$AS\" statusline"
rm -rf "$HOME/.claude"
err=$(PATH=$NOJQ "$AS" install-claude-statusline 2>&1 >/dev/null); rc=$?
is "install without jq exits 1 and says jq is required" "$rc:$(printf '%s\n' "$err" | grep -c 'jq is required')" "1:1"
is "install without jq writes nothing"               "$(find "$HOME/.claude" 2>/dev/null | wc -l | tr -d ' ')" 0
rm -rf "$NOJQ"

finish
