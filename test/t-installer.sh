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

finish
