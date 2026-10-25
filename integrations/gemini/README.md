# Gemini CLI

Gemini CLI's hooks live in `~/.gemini/settings.json` and look much like Claude
Code's. Merge [`settings-hooks.json`](settings-hooks.json) into yours (add the
entries to an existing `hooks` object if you have one).

| Gemini event | Word |
|---|---|
| `SessionStart` | idle |
| `BeforeAgent`, `AfterTool` | working |
| `Notification` matching `ToolPermission` | blocked (other notifications are not a wait) |
| `AfterAgent` | done |
| `SessionEnd` | clear |

Written from the Gemini CLI hooks reference, with the `ToolPermission`
matcher taken from workmux's shipped Gemini hooks; not exercised here.
