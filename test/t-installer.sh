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
cp "$FIX/.claude/settings.json.bak-agent-signal" "$FIX/first-backup"
HOME=$FIX "$AS" install-claude-hooks >/dev/null
is "re-running the installer is idempotent"      "$(jq '.hooks.Stop | length' "$FIX/.claude/settings.json")" 2
is "re-running keeps the original backup"        "$(cmp -s "$FIX/first-backup" "$FIX/.claude/settings.json.bak-agent-signal" && echo same)" same
is "installer leaves no temp files"              "$(find "$FIX/.claude" -name 'settings.json.??????' | wc -l | tr -d ' ')" 0
rm -rf "$FIX"

for f in integrations/gemini/settings-hooks.json integrations/copilot/hooks.json; do
  is "$f is valid JSON" "$(jq -e . "$ROOT/$f" >/dev/null 2>&1 && echo ok)" ok
done
is "integration hook files resolve the command through tmux, never a path" "$(grep -L 'tmux show -gv @agent_signal_command' "$ROOT"/integrations/*/*.json "$ROOT"/integrations/*/*.js "$ROOT"/integrations/*/*.ts | wc -l | tr -d ' ')" 0

is "plugin manifest is valid JSON with a name"       "$(jq -r .name "$ROOT/.claude-plugin/plugin.json")" tmux-agent-signal
is "marketplace lists the plugin at the repo root"     "$(jq -r '.plugins[0].source' "$ROOT/.claude-plugin/marketplace.json")" "./"
is "plugin hooks cover the same nine events as the installer" "$(jq -r '.hooks | keys | length' "$ROOT/hooks/hooks.json")" 9
is "plugin hooks locate the script via CLAUDE_PLUGIN_ROOT" "$(jq -r '.hooks[][].hooks[].command' "$ROOT/hooks/hooks.json" | grep -vc CLAUDE_PLUGIN_ROOT)" 0
is "plugin manifest version matches the script"        "$(jq -r .version "$ROOT/.claude-plugin/plugin.json")" "$(TMUX='' "$AS" version)"

finish
