#!/bin/sh
# Every hook command shipped for another agent (integrations/*/*.json), run
# for real through sh the way that agent would run it, against this server:
# each must find the script through @agent_signal_command, report the word its
# README promises under its own kind, and say nothing (Antigravity: exactly {}).
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

kind() { T display -p -t "$1" '#{@agent_kind}'; }
# A state and kind no integration ever reports, so every command must change both.
prime() { T set-option -p -t "$P_API" @agent_pane_state ask \; set-option -p -t "$P_API" @agent_kind primer; }

# shellcheck disable=SC2016  # $e is a jq variable, expanded by jq
filter() { # filter <file>: jq path to an event's commands
  case $1 in
    copilot/*)     printf '%s' '.hooks[$e][].bash' ;;
    antigravity/*) printf '%s' '.["tmux-agent-signal"][$e][].command' ;;
    *)             printf '%s' '.hooks[$e][].hooks[].command' ;;
  esac
}
events() { # events <file>: every event the file wires, sorted
  case $1 in
    antigravity/*) jq -r '.["tmux-agent-signal"] | keys[]' "$ROOT/integrations/$1" ;;
    *)             jq -r '.hooks | keys[]' "$ROOT/integrations/$1" ;;
  esac | sort
}

# file|kind|event|word, from each integration's README table.
cat > "$TMPDIR/table" <<'TABLE'
codex/hooks.json|codex|SessionStart|idle
codex/hooks.json|codex|UserPromptSubmit|working
codex/hooks.json|codex|PostToolUse|working
codex/hooks.json|codex|SubagentStart|working
codex/hooks.json|codex|SubagentStop|working
codex/hooks.json|codex|PermissionRequest|blocked
codex/hooks.json|codex|Stop|done
grok/hooks.json|grok|SessionStart|idle
grok/hooks.json|grok|UserPromptSubmit|working
grok/hooks.json|grok|PostToolUse|working
grok/hooks.json|grok|Notification|blocked
grok/hooks.json|grok|Stop|done
grok/hooks.json|grok|SessionEnd|clear
gemini/settings-hooks.json|gemini|SessionStart|idle
gemini/settings-hooks.json|gemini|BeforeAgent|working
gemini/settings-hooks.json|gemini|AfterTool|working
gemini/settings-hooks.json|gemini|Notification|blocked
gemini/settings-hooks.json|gemini|AfterAgent|done
gemini/settings-hooks.json|gemini|SessionEnd|clear
copilot/hooks.json|copilot|sessionStart|idle
copilot/hooks.json|copilot|userPromptSubmitted|working
copilot/hooks.json|copilot|postToolUse|working
copilot/hooks.json|copilot|postToolUseFailure|working
copilot/hooks.json|copilot|permissionRequest|blocked
copilot/hooks.json|copilot|agentStop|done
copilot/hooks.json|copilot|sessionEnd|clear
antigravity/hooks.json|agy|PreInvocation|working
antigravity/hooks.json|agy|Stop|done
TABLE

# The table covers every event each file wires, and nothing more.
for f in codex/hooks.json grok/hooks.json gemini/settings-hooks.json copilot/hooks.json antigravity/hooks.json; do
  is "$f: the table covers exactly the events it wires" \
    "$(awk -F'|' -v f="$f" '$1 == f {print $3}' "$TMPDIR/table" | sort | tr '\n' ' ')" "$(events "$f" | tr '\n' ' ')"
done

while IFS='|' read -r f k ev word <&3; do
  jq -r --arg e "$ev" "$(filter "$f")" "$ROOT/integrations/$f" > "$TMPDIR/cmds"
  is "$f $ev has a command" "$(grep -c . "$TMPDIR/cmds")" 1
  case $word in
    idle)  want_st=""; want_k=$k ;;
    clear) want_st=""; want_k="" ;;
    *)     want_st=$word; want_k=$k ;;
  esac
  case $f in antigravity/*) want_out="{}" ;; *) want_out="" ;; esac
  while IFS= read -r cmd <&4; do
    # Many events share one command text (every "working" in a file, every
    # "clear"): run each distinct text once and reuse its outcome.
    res="$TMPDIR/res.$(printf '%s' "$cmd" | cksum | tr ' ' _)"
    if [ ! -f "$res" ]; then
      prime
      out=$(TMUX_PANE=$P_API sh -c "$cmd" </dev/null 2>"$TMPDIR/err"); rc=$?
      printf '%s\n%s\n' "$rc [$out] [$(cat "$TMPDIR/err")]" "[$(pst "$P_API")] [$(kind "$P_API")]" > "$res"
    fi
    is "$f $ev -> $word: exits 0, stdout [$want_out], no stderr" "$(sed -n 1p "$res")" "0 [$want_out] []"
    is "$f $ev -> $word: pane state and kind" "$(sed -n 2p "$res")" "[$want_st] [$want_k]"
  done 4<"$TMPDIR/cmds"
done 3<"$TMPDIR/table"

# Where the agent's PATH has no tmux, the hook is a silent no-op, not an error.
NOTMUX="$TMPDIR/notmux"; mkdir -p "$NOTMUX"
cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$ROOT/integrations/codex/hooks.json")
prime
out=$(PATH=$NOTMUX TMUX_PANE=$P_API /bin/sh -c "$cmd" </dev/null 2>&1); rc=$?
is "codex Stop with no tmux on PATH exits 0 silently" "$rc [$out]" "0 []"
is "codex Stop with no tmux on PATH changes nothing"  "[$(pst "$P_API")] [$(kind "$P_API")]" "[ask] [primer]"

finish
