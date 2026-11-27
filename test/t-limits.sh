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
# `statusline` records in the background. That job inherits fd 3, so a pipe on
# fd 3 stays open until it has finished: when cat returns, the options are
# written. The command's own output and exit status pass through.
settled() { { "$@" 3>&1; echo $? > "$TMPDIR/rc"; } | cat; return "$(cat "$TMPDIR/rc")"; }
sl()    { printf '%s\n' "$1" | settled env PATH="$RUNPATH" AGENT_SIGNAL_NOW="${2:-$NOW}" "$AS" statusline; }   # sl <payload> [now]
put()   { T set-option -g "@agent_limit_$1" "$2"; }                                       # put <agent_window_field> <value>
recompute() { AGENT_SIGNAL_NOW=$NOW "$AS" limits; g @agent_limits; }

# What Claude Code 2.1 pipes to a statusLine command, cut down: the windows sit
# under rate_limits, and context_window has a used_percentage of its own.
payload() { # payload <rate_limits member, or nothing>
  printf '{"session_id":"abc","cwd":"/x","model":{"id":"claude-opus-5-5","display_name":"Opus"},"context_window":{"context_window_size":200000,"used_percentage":8,"remaining_percentage":92},"exceeds_200k_tokens":false%s,"vim":{"mode":"INSERT"}}' "${1:+,$1}"
}
FULL=$(payload "\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5,\"resets_at\":$R5},\"seven_day\":{\"used_percentage\":41.2,\"resets_at\":$R7}}")
WEEKDROP=$(payload "\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5,\"resets_at\":$R5},\"seven_day\":{\"used_percentage\":10,\"resets_at\":$R7}}")   # FULL, with the weekly figure down
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
out=$(settled "$AS" statusline "cat > '$TMPDIR/got'; echo one; echo two; exit 3" < "$TMPDIR/in"); rc=$?
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
  # ... but only for ten minutes: after that a lower figure is a real drop.
  sl "$(five 2 $((R5 + 18000)))" $((NOW + 599))
  is "$1: 9m59s after the record a lower figure is still refused" "$(g @agent_limit_claude_5h_used)" 5
  sl "$(five 2 $((R5 + 18000)))" $((NOW + 600))
  is "$1: after ten minutes a lower figure is taken"  "$(g @agent_limit_claude_5h_used):$(g @agent_limit_claude_at)" "2:$((NOW + 600))"

  # The two windows share one record time, read before either is written: the
  # weekly one can still drop once ten minutes are up, with the 5-hour one in
  # the same report.
  wipe; sl "$FULL"; sl "$WEEKDROP" $((NOW + 700))
  is "$1: after ten minutes the weekly figure drops, 5-hour window or not" "$(g @agent_limit_claude_7d_used)" 10

  # A window that has already reset is not a record: an idle session still
  # holding one must not put it over the live window, whenever it reports.
  wipe; sl "$(five 5 "$R5")"; sl "$(five 95 $((NOW + 600)))" $((NOW + 700))
  is "$1: an expired window never replaces a running one" "$(g @agent_limit_claude_5h_used):$(g @agent_limit_claude_5h_reset):$(g @agent_limits)" "5:$R5:C 95%"
  wipe; sl "$(five 95 $((NOW - 100)))"
  is "$1: and is not recorded on its own either"     "$(count)" 0

  # The same numbers again are not written again (every write makes tmux
  # repaint): the record time moves at most every five minutes.
  wipe; sl "$FULL"; sl "$FULL" $((NOW + 299))
  is "$1: the same report within five minutes leaves the record time" "$(g @agent_limit_claude_at)" "$NOW"
  sl "$FULL" $((NOW + 300))
  is "$1: after five minutes the record time is brought up to date" "$(g @agent_limit_claude_at)" "$((NOW + 300))"

  # Only the windows under rate_limits count, wherever else the names turn up.
  wipe; sl "{\"before\":{\"five_hour\":{\"used_percentage\":88,\"resets_at\":$R7}},\"rate_limits\":{\"five_hour\":{\"used_percentage\":12,\"resets_at\":$R5}},\"after\":{\"five_hour\":{\"used_percentage\":99},\"seven_day\":{\"used_percentage\":77}}}"
  is "$1: a five_hour outside rate_limits is not the window" "$(g @agent_limit_claude_5h_used):$(g @agent_limit_claude_5h_reset)" "12:$R5"

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
out=$(settled env AGENT_SIGNAL_NOW="$NOW" "$AS" statusline "cat > '$TMPDIR/got'; echo one; echo two; exit 3" < "$TMPDIR/in"); rc=$?
is "chain: the previous command gets the identical stdin" "$(cmp -s "$TMPDIR/in" "$TMPDIR/got" && echo same)" same
is "chain: its output is printed"                   "$(printf '%s' "$out" | tr '\n' ' ')" "one two"
is "chain: its exit status is kept"                 "$rc" 3
is "chain: and the limits were still recorded"      "$(g @agent_limit_claude_5h_used)" 23
T set-option -g @agent_signal_statusline_next 'echo from-option'
is "chain: @agent_signal_statusline_next names the command" "$(settled "$AS" statusline < "$TMPDIR/in")" from-option
is "chain: an argument wins over the option"        "$(settled "$AS" statusline 'echo from-arg' < "$TMPDIR/in")" from-arg
is "chain: a command written as several words is run whole" "$(settled "$AS" statusline echo several   words < "$TMPDIR/in")" "several words"
T set-option -gu @agent_signal_statusline_next
is "chain: outside tmux the previous command still runs" "$(TMUX='' "$AS" statusline 'cat' < "$TMPDIR/in")" "$FULL"

# --- recording never holds the status line up --------------------------------
# A tmux that does not answer until the gate file appears. If statusline
# waited for the recording, it would come back with the options already
# written (after the five seconds the stand-in gives up at).
wipe; SLOW=$(mktemp -d); GATE="$TMPDIR/gate"
# shellcheck disable=SC2016  # $i and $@ belong to the stand-in script
printf '#!/bin/sh\ni=0; while [ ! -e "%s" ] && [ $i -lt 100 ]; do sleep 0.05; i=$((i + 1)); done\nexec "%s" "$@"\n' "$GATE" "$(command -v tmux)" > "$SLOW/tmux"; chmod +x "$SLOW/tmux"
out=$(PATH=$SLOW:$PATH AGENT_SIGNAL_NOW=$NOW "$AS" statusline 'cat >/dev/null; echo drawn' < "$TMPDIR/in")
is "the status line is drawn while the recording is still waiting" "$out:$(count)" "drawn:0"
: > "$GATE"; i=0; while [ -z "$(g @agent_limits)" ] && [ $i -lt 100 ]; do sleep 0.05; i=$((i + 1)); done
is "and the recording lands once tmux answers"      "$(g @agent_limit_claude_5h_used):$(g @agent_limits)" "23:C 77% w59%"
rm -rf "$SLOW" "$GATE"

# --- two sessions reporting at once ------------------------------------------
# A fresh session and a stale one race. Whichever lands last, each window's
# used and reset must come from the same report, never one from each.
LATE5=$((R5 + 18000)); LATE7=$((R7 + 604800))
FRESH=$(payload "\"rate_limits\":{\"five_hour\":{\"used_percentage\":5,\"resets_at\":$LATE5},\"seven_day\":{\"used_percentage\":10,\"resets_at\":$LATE7}}")
STALE=$(payload "\"rate_limits\":{\"five_hour\":{\"used_percentage\":95,\"resets_at\":$R5},\"seven_day\":{\"used_percentage\":90,\"resets_at\":$R7}}")
race() { printf '%s\n' "$1" | AGENT_SIGNAL_NOW=$NOW "$AS" statusline 3>&1 | cat; }   # returns once the recording has finished
i=0; mixed=""
while [ $i -lt 10 ]; do
  wipe; race "$FRESH" & race "$STALE" & wait
  for w in 5h 7d; do
    pair="$(g "@agent_limit_claude_${w}_used"):$(g "@agent_limit_claude_${w}_reset")"
    case $pair in "5:$LATE5"|"95:$R5"|"10:$LATE7"|"90:$R7") ;; *) mixed="$mixed $w=$pair" ;; esac
  done
  i=$((i + 1))
done
is "ten races: used and reset always come from the same report" "$mixed" ""
sl "$FRESH"
is "and the next fresh report is the one that stands" "$(g @agent_limit_claude_5h_used):$(g @agent_limit_claude_5h_reset):$(g @agent_limit_claude_7d_used)" "5:$LATE5:10"

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
  wipe; { tc "$(rl "$(cw 21 299 "$R5")" "$(cw 62 10079 "$R7")")"; } | rollout a; codex_done
  is "$1: lengths a minute short are the same windows" "$(g @agent_limit_codex_5h_used):$(g @agent_limit_codex_7d_used)" "21:62"
  wipe; { tc "$(rl "$(cw 50 290 "$R5")" "$(cw 50 10100 "$R7")")"; } | rollout a; codex_done
  is "$1: lengths well off are not"                  "$(count)" 0
  wipe; { tc "$(rl "$(cw 50 43200 "$R7")" null)"; } | rollout a; codex_done
  is "$1: a monthly window is not recorded"          "$(count)" 0
  wipe; { tc "$(rl '{"used_percent":20,"window_minutes":300,"resets_in_seconds":600}' '{"used_percent":3.0,"window_minutes":10080}')"; } | rollout a; codex_done
  is "$1: resets_in_seconds counts from now"         "$(g @agent_limit_codex_5h_reset)" "$((NOW + 600))"
  is "$1: with neither reset field no reset is stored" "$(g @agent_limit_codex_7d_used):$(T show-options -g | grep -c '^@agent_limit_codex_7d_reset')" "3:0"

  # A record with no reset belongs to the stored window while that has not reset.
  wipe; { tc "$(rl "$(cw 50 300 "$R5")" null)"; } | rollout a; codex_done
  { tc "$(rl '{"used_percent":10,"window_minutes":300}' null)"; } | rollout a; codex_done
  is "$1: a report with no reset does not undo the stored window" "$(g @agent_limit_codex_5h_used):$(g @agent_limit_codex_5h_reset)" "50:$R5"
  { tc "$(rl '{"used_percent":55,"window_minutes":300}' null)"; } | rollout a; codex_done
  is "$1: and a higher one keeps the stored reset"   "$(g @agent_limit_codex_5h_used):$(g @agent_limit_codex_5h_reset)" "55:$R5"

  # Two logs: the one written last is read, the older one never.
  wipe; { tc "$(rl "$(cw 90 300 $((R5 + 999)))" null)"; } | rollout old; sleep 1.1
  { tc "$(rl "$(cw 33 300 "$R5")" null)"; } > "$DAY/rollout-2026-11-26T02-00-00-0199a0b1-new.jsonl"; codex_done
  is "$1: the newest rollout file is the one read"   "$(g @agent_limit_codex_5h_used)" 33

  # Models metered apart report under their own limit_id: the main allowance
  # ("codex", or no id) is the one shown, wherever it sits in the tail.
  ol() { printf '{"limit_id":"codex_other","primary":%s,"secondary":null}' "$1"; }
  wipe; { tc "$(rl "$(cw 60 300 "$R5")" null)"; other; tc "$(ol "$(cw 3 300 "$R5")")"; other; } | rollout a; codex_done
  is "$1: a record for another limit_id does not hide the main one" "$(g @agent_limit_codex_5h_used)" 60
  wipe; { tc "{\"primary\":$(cw 61 300 "$R5"),\"secondary\":null}"; tc "$(ol "$(cw 3 300 "$R5")")"; } | rollout a; codex_done
  is "$1: a record with no limit_id counts as the main one" "$(g @agent_limit_codex_5h_used)" 61
  wipe; { tc "$(ol "$(cw 3 300 "$R5")")"; } | rollout a; codex_done
  is "$1: with no main record in the tail the last one is used" "$(g @agent_limit_codex_5h_used)" 3

  # A sessions directory that is a symlink (kept on another disk, say).
  wipe; { tc "$(rl "$(cw 17 300 "$R5")" null)"; } | rollout a
  mv "$CX/sessions" "$TMPDIR/elsewhere"; ln -s "$TMPDIR/elsewhere" "$CX/sessions"; codex_done
  is "$1: a symlinked sessions directory is followed" "$(g @agent_limit_codex_5h_used)" 17
  rm -rf "$TMPDIR/elsewhere"

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

# --- switching it off again --------------------------------------------------
T set-option -g @agent_signal_limits off
hook "$P_API" UserPromptSubmit
is "off again: an agent event leaves the options as they are" "$(g @agent_limits)" "X 40%"
"$AS" limits
is "off again: \`limits\` takes the meter and its data away" "$(T show-options -g | grep -c '^@agent_limit')" 0
put codex_at "$NOW"; put codex_5h_used 60; T set-option -g @agent_limits "X 40%"
sh "$ROOT/agent-signal.tmux"
is "off again: so does loading the plugin"           "$(T show-options -g | grep -c '^@agent_limit')" 0
T set-option -g @agent_signal_limits on
put codex_at "$NOW"; put codex_5h_used 60
sh "$ROOT/agent-signal.tmux"
is "on: loading the plugin leaves the data alone"    "$(g @agent_limit_codex_5h_used)" 60
recompute >/dev/null

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
is "the installed command still runs the user's status line" "$(settled env AGENT_SIGNAL_NOW="$NOW" sh -c "$(jq -r '.statusLine.command' "$S")" < "$TMPDIR/in")" "it's mine"
is "and records the limits on the way"               "$(g @agent_limit_claude_5h_used)" 23
is "check sees the statusLine wired"                 "$("$AS" check | grep -c 'ok   Claude Code statusLine runs agent-signal statusline')" 1
first=$(jq -c '.statusLine' "$S")
"$AS" install-claude-statusline >/dev/null
is "re-running install changes nothing"              "$(jq -c '.statusLine' "$S")" "$first"
is "and the original is still the one kept"          "$(jq -c .original "$S.statusline-agent-signal")" "$ORIG"

# A settings.json that stops parsing must not cost the kept original.
cp "$S" "$TMPDIR/good"; printf '{"statusLine": {,}\n' > "$S"
err=$("$AS" install-claude-statusline 2>&1 >/dev/null); rc=$?
is "install on a broken settings.json exits 1 and says so" "$rc:$(printf '%s\n' "$err" | grep -c 'not valid JSON')" "1:1"
is "and the kept original is untouched"              "$(jq -c .original "$S.statusline-agent-signal")" "$ORIG"
cp "$TMPDIR/good" "$S"

# settings.json as a symlink into a dotfiles repo, with its own mode. (The
# link here is relative, as a dotfiles manager would make it.)
mkdir -p "$TMPDIR/dotfiles"; mv "$S" "$TMPDIR/dotfiles/settings.json"; ln -s ../dotfiles/settings.json "$S"; chmod 644 "$TMPDIR/dotfiles/settings.json"
"$AS" uninstall >/dev/null; "$AS" install-claude-statusline >/dev/null
is "install and uninstall write through a symlinked settings.json" "$([ -L "$S" ] && echo link):$(jq -r '.statusLine.command' "$TMPDIR/dotfiles/settings.json" | grep -c statusline)" "link:1"
is "and leave its mode alone"                        "$(find "$TMPDIR/dotfiles/settings.json" -perm 644 | wc -l | tr -d ' ')" 1
is "and leave no temp file beside the real file"     "$(find "$TMPDIR/dotfiles" -type f | wc -l | tr -d ' ')" 1
rm "$S"; mv "$TMPDIR/dotfiles/settings.json" "$S"
is "install leaves no temp files"                    "$(find "$HOME/.claude" -name 'settings.json.??????' | wc -l | tr -d ' ')" 0
"$AS" uninstall >/dev/null
is "uninstall restores the original statusLine exactly" "$(jq -c '.statusLine' "$S")" "$ORIG"
is "uninstall keeps unrelated settings"              "$(jq -c '[.model, .hooks]' "$S")" '["x",{}]'
is "uninstall removes the kept copy and leaves no temp files" "$(find "$HOME/.claude" -type f | wc -l | tr -d ' ')" 1
is "uninstall unsets the recorded limits and @agent_limits" "$(T show-options -g | grep -c '^@agent_limit')" 0
"$AS" uninstall >/dev/null
is "a second uninstall leaves the statusLine alone"  "$(jq -c '.statusLine' "$S")" "$ORIG"

# Outside tmux uninstall still has the statusLine to put back, and says that
# it left the server alone.
printf '{"model":"x","statusLine":%s}\n' "$ORIG" > "$S"
"$AS" install-claude-statusline >/dev/null
out=$(TMUX='' "$AS" uninstall); rc=$?
is "uninstall outside tmux restores the statusLine"  "$rc:$(jq -c '.statusLine' "$S")" "0:$ORIG"
is "and says the server was left alone"              "$(printf '%s\n' "$out" | grep -c 'not inside tmux')" 1

# A statusLine set by hand to the bare command, as the no-jq message tells you
# to: the installer takes it over, and uninstall can then remove it.
printf '{"model":"x","statusLine":{"type":"command","command":"\\"/old/place/bin/agent-signal\\" statusline","padding":1}}\n' > "$S"
"$AS" install-claude-statusline >/dev/null; rc=$?
is "install adopts a bare hand-wired statusLine"     "$rc:$(jq -c '.statusLine' "$S")" "0:{\"type\":\"command\",\"command\":\"\\\"$AS\\\" statusline\",\"padding\":1}"
"$AS" uninstall >/dev/null
is "and uninstall then removes it"                   "$(jq -c . "$S")" '{"model":"x"}'
# One set by hand with a command of its own cannot be taken apart: left alone.
printf '{"statusLine":{"type":"command","command":"/old/place/bin/agent-signal statusline mine.sh"}}\n' > "$S"
err=$("$AS" install-claude-statusline 2>&1 >/dev/null); rc=$?
is "install leaves a hand-wired chain alone and says why" "$rc:$(printf '%s\n' "$err" | grep -c 'set by hand')" "1:1"

# No statusLine to begin with: one is added, and uninstall takes it away again.
printf '{"model":"x"}\n' > "$S"
"$AS" install-claude-statusline >/dev/null
is "with no statusLine, install adds a bare one"     "$(jq -c '.statusLine' "$S")" "{\"type\":\"command\",\"command\":\"\\\"$AS\\\" statusline\"}"
"$AS" uninstall >/dev/null
is "and uninstall removes it again"                  "$(jq -c . "$S")" '{"model":"x"}'
# A wrapper the user has edited since is theirs too: neither command undoes it.
printf '{"model":"x","statusLine":%s}\n' "$ORIG" > "$S"
"$AS" install-claude-statusline >/dev/null
jq --arg c "\"$AS\" statusline 'echo edited'" '.statusLine.command = $c | .statusLine.padding = 0' "$S" > "$S.new" && mv "$S.new" "$S"
edited=$(jq -c '.statusLine' "$S")
out=$("$AS" uninstall)
is "uninstall leaves an edited wrapper alone"        "$(jq -c '.statusLine' "$S")" "$edited"
is "and says so, pointing at the kept original"      "$(printf '%s\n' "$out" | grep -c 'edited since it was installed')" 1
err=$("$AS" install-claude-statusline 2>&1 >/dev/null); rc=$?
is "install refuses to rewrap an edited wrapper"     "$rc:$(jq -c '.statusLine' "$S"):$(printf '%s\n' "$err" | grep -c 'nothing changed')" "1:$edited:1"
is "the original is still kept for the user"         "$(jq -c .original "$S.statusline-agent-signal")" "$ORIG"
out=$(PATH=$NOJQ "$AS" uninstall)
is "uninstall without jq says the statusLine is left" "$(printf '%s\n' "$out" | grep -c 'jq not found, so statusLine')" 1
rm -f "$S.statusline-agent-signal"; printf '{"model":"x"}\n' > "$S"

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
