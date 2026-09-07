#!/bin/sh
# End-to-end tests against an isolated tmux server. No daemon, no mocks: the
# real script drives a real server (-L agent-signal-test, -f /dev/null).
#
#   sh test/run.sh          run everything
#   KEEP=1 sh test/run.sh   leave the server running for inspection
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
AS="$ROOT/bin/agent-signal"
SOCK=agent-signal-test
T() { tmux -L "$SOCK" "$@"; }

pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n       got: [%s]  want: [%s]\n' "$1" "$2" "$3"; }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }
strip() { sed 's/#\[[^]]*\]//g'; }

# --- fixture ---------------------------------------------------------------
T kill-server 2>/dev/null
T -f /dev/null new-session -d -s main -n shell -x 120 -y 30
T set-option -g @agent_signal_sound off          # no afplay in CI
T set-option -g @agent_signal_tab_colour on
# The scripts talk to whatever server $TMUX points at, so point it at ours.
TMUX="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCK,0,0"; export TMUX
sh "$ROOT/agent-signal.tmux"

W_API=$(T new-window -d -n api -P -F '#{window_id}')
W_WEB=$(T new-window -d -n web -P -F '#{window_id}')
P_API=$(T list-panes -t "$W_API" -F '#{pane_id}')
P_WEB=$(T list-panes -t "$W_WEB" -F '#{pane_id}')
P_WEB2=$(T split-window -d -t "$W_WEB" -P -F '#{pane_id}')

hook() { # hook <pane> <event> [json]
  printf '%s' "${3:-{\}}" | TMUX_PANE=$1 "$AS" hook "$2"
}
wst()  { T show-option -wqv -t "$1" @agent_state; }
wicon(){ T show-option -wqv -t "$1" @agent_icon; }
wstyle(){ T show-option -wqv -t "$1" window-status-style; }
pst()  { T display -p -t "$1" '#{@agent_pane_state}'; }
gneeds(){ T show-option -gqv @agent_needs; }
gsum() { T show-option -gqv @agent_summary | strip; }

echo "entry file"
case $(T show-option -gv window-status-format) in *@agent_icon*) ok "badge appended to window-status-format" ;; *) bad "badge appended" "$(T show-option -gv window-status-format)" "...@agent_icon..." ;; esac
case $(T show-option -gv status-right) in "#{@agent_summary}"*) ok "summary prepended to status-right" ;; *) bad "summary prepended" "$(T show-option -gv status-right)" "#{@agent_summary}..." ;; esac
is "next key bound"     "$(T list-keys -T prefix | grep -c 'agent-signal next')" 1
is "seen hook installed" "$(T show-hooks -g | grep -c 'after-select-window\[91\]')" 1

echo "claude hook mapping (hidden window)"
hook "$P_API" SessionStart
is "SessionStart -> idle"            "$(wst "$W_API")" ""
hook "$P_API" UserPromptSubmit
is "UserPromptSubmit -> working"     "$(wst "$W_API")" working
is "working icon"                    "$(wicon "$W_API")" "~"
is "working leaves tab colour alone" "$(wstyle "$W_API")" ""
hook "$P_API" PreToolUse '{"tool_name":"Bash"}'
is "PreToolUse Bash -> working"      "$(wst "$W_API")" working
hook "$P_API" PreToolUse '{"tool_name":"AskUserQuestion"}'
is "PreToolUse AskUserQuestion -> ask" "$(wst "$W_API")" ask
is "ask counts as needing you"       "$(gneeds)" 1
hook "$P_API" PostToolUse '{"tool_name":"AskUserQuestion"}'
is "PostToolUse -> working"          "$(wst "$W_API")" working
hook "$P_API" PermissionRequest
is "PermissionRequest -> blocked"    "$(wst "$W_API")" blocked
is "blocked colours the tab"         "$(wstyle "$W_API")" "fg=black,bg=colour208,bold"
hook "$P_API" Notification '{"notification_type":"permission_prompt"}'
is "Notification permission_prompt -> blocked" "$(wst "$W_API")" blocked
hook "$P_API" Stop '{"background_tasks":[{"id":"x"}]}'
is "Stop with background task -> working" "$(wst "$W_API")" working
hook "$P_API" Stop '{"background_tasks":[]}'
is "Stop -> done (window hidden)"    "$(wst "$W_API")" "done"
is "done colours the tab green"      "$(wstyle "$W_API")" "fg=black,bg=green,bold"
is "done does not count as needing you" "$(gneeds)" ""

echo "idle reminder"
hook "$P_API" Notification '{"notification_type":"idle_prompt"}'
is "idle_prompt on a done pane leaves it done" "$(wst "$W_API")" "done"
T set-option -up -t "$P_API" @agent_pane_state; "$AS" seen >/dev/null 2>&1; T set-option -uw -t "$W_API" @agent_state
hook "$P_API" Notification '{"notification_type":"idle_prompt"}'
is "idle_prompt on an idle pane stays idle" "$(wst "$W_API")" ""
hook "$P_API" PreToolUse '{"tool_name":"Bash"}'
hook "$P_API" Notification '{"notification_type":"idle_prompt"}'
is "idle_prompt rescues an interrupted turn -> done" "$(wst "$W_API")" "done"

echo "no tmux on PATH"
# With PATH empty the scripts must fall back to a known install path or exit 0,
# never die on an unbound variable.
is "entry file survives an empty PATH"  "$(PATH=/nonexistent /bin/sh "$ROOT/agent-signal.tmux" 2>&1 | grep -c unbound; echo "rc=$?")" "0
rc=1"
is "switcher survives an empty PATH"    "$(PATH=/nonexistent /bin/sh "$ROOT/scripts/switcher.sh" </dev/null 2>&1 | grep -c unbound)" 0

echo "hook exit codes"
printf '{"notification_type":"idle_prompt"}' | TMUX_PANE=$P_API "$AS" hook Notification; rc=$?
is "idle_prompt on a pane with nothing to rescue exits 0" "$rc" 0

echo "concurrent hooks"
# Two hooks for panes in the same window racing: the blocked one must win.
W_RACE=$(T new-window -d -n race -P -F '#{window_id}')
P_R1=$(T list-panes -t "$W_RACE" -F '#{pane_id}'); P_R2=$(T split-window -d -t "$W_RACE" -P -F '#{pane_id}')
i=0; while [ $i -lt 10 ]; do
  hook "$P_R1" PostToolUse & hook "$P_R2" PermissionRequest & wait
  [ "$(wst "$W_RACE")" = blocked ] || break
  hook "$P_R2" PostToolUse; i=$((i + 1))
done
is "10 racing PostToolUse/PermissionRequest rounds all ended blocked" "$i" 10
hook "$P_R1" SessionEnd; hook "$P_R2" SessionEnd; T kill-window -t "$W_RACE"
is "no lock directories left behind" "$(ls -d "${TMPDIR:-/tmp}"/agent-signal.*.lock.* 2>/dev/null | wc -l | tr -d ' ')" 0

echo "viewed -> idle"
T select-window -t "$W_API"; sleep 0.5
is "viewing a done window clears it (after-select-window hook)" "$(wst "$W_API")" ""
is "all three seen hooks name their own window" "$(T show-hooks -g | grep -c 'seen #{window_id}')" 3
hook "$P_WEB" Stop
"$AS" seen "$W_WEB"
is "seen with an explicit window clears that window" "$(wst "$W_WEB")" ""
hook "$P_API" UserPromptSubmit; hook "$P_API" Stop
# No client is attached to the test server, so nobody is "looking": done must show.
is "finishing in the active window of a detached session still shows done" "$(wst "$W_API")" "done"
hook "$P_API" SessionEnd
T select-window -t "$W_WEB"; sleep 0.3

echo "theme safety"
T set-option -w -t "$W_WEB" window-status-style 'fg=cyan,bg=blue'
hook "$P_WEB" UserPromptSubmit
is "a user's per-window style survives a working state" "$(wstyle "$W_WEB")" "fg=cyan,bg=blue"
hook "$P_WEB" PermissionRequest
is "blocked overrides it while flagged"  "$(wstyle "$W_WEB")" "fg=black,bg=colour208,bold"
hook "$P_WEB" SessionEnd
is "clearing removes only our style"    "$(wstyle "$W_WEB")" ""
T set-option -uw -t "$W_WEB" window-status-style

echo "multi-pane aggregation"
hook "$P_WEB" UserPromptSubmit
hook "$P_WEB2" PermissionRequest
is "blocked pane outranks working pane" "$(wst "$W_WEB")" blocked
hook "$P_WEB" PermissionRequest
is "two blocked panes in one window count as one window needing you" "$(gneeds)" 1
hook "$P_WEB2" PostToolUse
hook "$P_WEB" Stop
is "done outranks working"           "$(wst "$W_WEB")" "done"
hook "$P_WEB2" Stop
hook "$P_WEB" SessionEnd
is "SessionEnd clears its pane only" "$(pst "$P_WEB")" ""
is "window keeps the other pane's state" "$(wst "$W_WEB")" "done"

echo "wait and park"
"$AS" hold wait "$W_WEB"
is "wait icon"                       "$(wicon "$W_WEB")" "…"
hook "$P_WEB2" UserPromptSubmit
is "new event clears wait"           "$(T show-option -wqv -t "$W_WEB" @agent_hold)" ""
"$AS" hold park "$W_WEB"
is "park set"                        "$(T show-option -wqv -t "$W_WEB" @agent_hold)" park
hook "$P_WEB2" PermissionRequest
is "blocked shows through park"      "$(wicon "$W_WEB")" "!"
"$AS" hold park "$W_WEB"
is "park toggles off"                "$(T show-option -wqv -t "$W_WEB" @agent_hold)" ""

echo "next"
T select-window -t "$W_API"
hook "$P_API" Stop                                   # api: done (hidden? no, visible -> idle)
hook "$P_WEB2" PermissionRequest                     # web: blocked
"$AS" next
is "next jumps to the blocked window" "$(T display -p '#{window_id}')" "$W_WEB"
hook "$P_WEB2" Stop; T select-window -t "$W_API"; sleep 0.3
"$AS" hold park "$W_WEB"
"$AS" next
is "next skips a parked window"      "$(T display -p '#{window_id}')" "$W_API"
"$AS" hold clear "$W_WEB"

echo "awkward names"
T rename-session -t main 'my proj'
hook "$P_WEB2" PermissionRequest; T select-window -t "$W_API"
"$AS" next
is "next finds a blocked window in a session whose name has a space" "$(T display -p '#{window_id}')" "$W_WEB"
hook "$P_WEB2" Stop; T select-window -t "$W_API"; sleep 0.3
T rename-session -t 'my proj' main
T rename-window -t "$W_WEB" ''
is "list survives an empty window name" "$("$AS" list 2>&1 | grep -c 'integer expression')" 0
T rename-window -t "$W_WEB" web

echo "summary and listing"
hook "$P_API" UserPromptSubmit
case $(gsum) in *"✳$(T display -p -t "$W_API" '#{window_index}')"*) ok "summary shows glyph+window index" ;; *) bad "summary" "$(gsum)" "...✳<index>..." ;; esac
is "summary entries are space separated" "$(gsum | tr -cd ' ' | wc -c | tr -d ' ')" 2
is "summary leaves no temp files"         "$(ls "${TMPDIR:-/tmp}"/agent-signal.[0-9]* 2>/dev/null | wc -l | tr -d ' ')" 0
is "list has session, window and pane rows" "$("$AS" list | cut -f1 | sort -u | tr -d '\n')" "PSW"
T set-option -g @agent_signal_ascii on; hook "$P_API" Stop
is "ascii preset uses + for done"    "$(wicon "$W_API")" "+"
T set-option -gu @agent_signal_ascii

echo "installer"
FIX=$(mktemp -d); mkdir -p "$FIX/.claude"
printf '{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"echo mine"}]}]},"model":"x"}\n' > "$FIX/.claude/settings.json"
HOME=$FIX "$AS" install-claude-hooks >/dev/null
is "installer keeps the user's existing Stop hook" "$(jq -r '.hooks.Stop[0].hooks[0].command' "$FIX/.claude/settings.json")" "echo mine"
is "installer keeps unrelated settings"          "$(jq -r '.model' "$FIX/.claude/settings.json")" x
is "installer registers all nine events"         "$(jq '.hooks | keys | length' "$FIX/.claude/settings.json")" 9
is "installer quotes the plugin path"            "$(jq -r '.hooks.StopFailure[0].hooks[0].command' "$FIX/.claude/settings.json" | cut -c1)" '"'
cp "$FIX/.claude/settings.json.bak-agent-signal" "$FIX/first-backup"
HOME=$FIX "$AS" install-claude-hooks >/dev/null
is "re-running the installer is idempotent"      "$(jq '.hooks.Stop | length' "$FIX/.claude/settings.json")" 2
is "re-running keeps the original backup"        "$(cmp -s "$FIX/first-backup" "$FIX/.claude/settings.json.bak-agent-signal" && echo same)" same
is "installer leaves no temp files"              "$(ls "$FIX/.claude/" | grep -c 'settings.json\.[A-Za-z0-9]\{6\}$')" 0
rm -rf "$FIX"

echo "clear"
hook "$P_API" SessionEnd; hook "$P_WEB2" SessionEnd
is "all state cleared"               "$(T list-panes -a -F '#{@agent_pane_state}' | tr -d '\n')" ""
is "summary cleared"                 "$(gsum)" ""

[ "${KEEP:-}" = 1 ] || T kill-server
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
