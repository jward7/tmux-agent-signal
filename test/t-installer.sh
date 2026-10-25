#!/bin/sh
# `install-claude-hooks` merging into an existing ~/.claude/settings.json.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup_env

FIX=$(mktemp -d); mkdir -p "$FIX/.claude"
printf '{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"echo mine"}]}]},"model":"x"}\n' > "$FIX/.claude/settings.json"
HOME=$FIX "$AS" install-claude-hooks >/dev/null
is "installer keeps the user's existing Stop hook" "$(jq -r '.hooks.Stop[0].hooks[0].command' "$FIX/.claude/settings.json")" "echo mine"
is "installer keeps unrelated settings"          "$(jq -r '.model' "$FIX/.claude/settings.json")" x
is "installer registers all nine events"         "$(jq '.hooks | keys | length' "$FIX/.claude/settings.json")" 9
is "installer quotes the plugin path"            "$(jq -r '.hooks.StopFailure[0].hooks[0].command' "$FIX/.claude/settings.json" | cut -c1)" '"'
is "installer skips compaction for SessionStart" "$(jq -r '.hooks.SessionStart[0].matcher' "$FIX/.claude/settings.json")" "startup|resume|clear|fork"
is "installer leaves other matchers open"        "$(jq -r '.hooks.PreToolUse[0].matcher' "$FIX/.claude/settings.json")" ""
cp "$FIX/.claude/settings.json.bak-agent-signal" "$FIX/first-backup"
HOME=$FIX "$AS" install-claude-hooks >/dev/null
is "re-running the installer is idempotent"      "$(jq '.hooks.Stop | length' "$FIX/.claude/settings.json")" 2
is "re-running keeps the original backup"        "$(cmp -s "$FIX/first-backup" "$FIX/.claude/settings.json.bak-agent-signal" && echo same)" same
is "installer leaves no temp files"              "$(find "$FIX/.claude" -name 'settings.json.??????' | wc -l | tr -d ' ')" 0
rm -rf "$FIX"

# No settings.json at all (nor ~/.claude): the installer starts one.
FIX=$(mktemp -d)
HOME=$FIX "$AS" install-claude-hooks >/dev/null; rc=$?
is "installer with no settings.json exits 0"     "$rc" 0
is "installer creates settings.json with all nine events" "$(jq -c '.hooks | keys' "$FIX/.claude/settings.json")" '["Notification","PermissionRequest","PostToolUse","PreToolUse","SessionEnd","SessionStart","Stop","StopFailure","UserPromptSubmit"]'
is "every installed hook is async"               "$(jq '[.hooks[][].hooks[] | select(.async != true)] | length' "$FIX/.claude/settings.json")" 0
rm -rf "$FIX"

# A legacy entry from before the path was quoted is replaced, not duplicated.
FIX=$(mktemp -d); mkdir -p "$FIX/.claude"
printf '{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"/old/plugin/bin/agent-signal hook Stop"}]}]}}\n' > "$FIX/.claude/settings.json"
HOME=$FIX "$AS" install-claude-hooks >/dev/null
is "a legacy unquoted entry is replaced, not duplicated" "$(jq '.hooks.Stop | length' "$FIX/.claude/settings.json")" 1
is "the replacement is the quoted command"       "$(jq -r '.hooks.Stop[0].hooks[0].command' "$FIX/.claude/settings.json")" "\"$AS\" hook Stop"
rm -rf "$FIX"

# Without jq the installer refuses, says why, and writes nothing.
FIX=$(mktemp -d); NOJQ=$(mktemp -d)
for b in sh tmux dirname; do ln -s "$(command -v "$b")" "$NOJQ/$b"; done
err=$(HOME=$FIX PATH=$NOJQ "$AS" install-claude-hooks 2>&1 >/dev/null); rc=$?
is "installer without jq exits 1"                "$rc" 1
is "installer without jq says jq is required"    "$(printf '%s\n' "$err" | grep -c 'jq is required')" 1
is "installer without jq writes nothing"         "$(find "$FIX" -mindepth 1 | wc -l | tr -d ' ')" 0
rm -rf "$FIX" "$NOJQ"

for f in $(cd "$ROOT" && find integrations -name '*.json' | sort); do
  is "$f is valid JSON" "$(jq -e . "$ROOT/$f" >/dev/null 2>&1 && echo ok)" ok
done
is "every integration JSON file was checked (codex, grok, gemini, copilot, antigravity)" "$(cd "$ROOT" && find integrations -name '*.json' | sed 's|^integrations/||; s|/.*||' | sort -u | grep -cxE 'antigravity|codex|copilot|gemini|grok')" 5
is "integration hook files resolve the command through tmux, never a path" "$(grep -L 'tmux show -gv @agent_signal_command' "$ROOT"/integrations/*/*.json "$ROOT"/integrations/*/*.js "$ROOT"/integrations/*/*.ts | wc -l | tr -d ' ')" 0

is "plugin manifest is valid JSON with a name"       "$(jq -r .name "$ROOT/.claude-plugin/plugin.json")" tmux-agent-signal
is "marketplace lists the plugin at the repo root"     "$(jq -r '.plugins[0].source' "$ROOT/.claude-plugin/marketplace.json")" "./"
is "plugin hooks cover the same nine events as the installer" "$(jq -r '.hooks | keys | length' "$ROOT/hooks/hooks.json")" 9
is "every plugin hook is async"                 "$(jq '[.hooks[][].hooks[] | select(.async != true)] | length' "$ROOT/hooks/hooks.json")" 0
is "every docs hook is async"                   "$(jq '[.hooks[][].hooks[] | select(.async != true)] | length' "$ROOT/docs/claude-hooks.json")" 0
is "docs hooks cover the same nine events as the plugin" "$(jq -c '.hooks | keys' "$ROOT/docs/claude-hooks.json")" "$(jq -c '.hooks | keys' "$ROOT/hooks/hooks.json")"
is "plugin hooks skip compaction for SessionStart" "$(jq -r '.hooks.SessionStart[0].matcher' "$ROOT/hooks/hooks.json")" "startup|resume|clear|fork"
is "docs hooks skip compaction for SessionStart"   "$(jq -r '.hooks.SessionStart[0].matcher' "$ROOT/docs/claude-hooks.json")" "startup|resume|clear|fork"
is "plugin hooks locate the script via CLAUDE_PLUGIN_ROOT" "$(jq -r '.hooks[][].hooks[].command' "$ROOT/hooks/hooks.json" | grep -vc CLAUDE_PLUGIN_ROOT)" 0
is "plugin manifest version matches the script"        "$(jq -r .version "$ROOT/.claude-plugin/plugin.json")" "$(TMUX='' "$AS" version)"
is "marketplace entry version matches the script"      "$(jq -r '.plugins[0].version' "$ROOT/.claude-plugin/marketplace.json")" "$(TMUX='' "$AS" version)"

finish
