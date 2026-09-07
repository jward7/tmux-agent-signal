# Gemini CLI

Gemini CLI's hooks live in `~/.gemini/settings.json` and look much like Claude
Code's. Merge [`settings-hooks.json`](settings-hooks.json) into yours (add the
entries to an existing `hooks` object if you have one).

| Gemini event | Word |
|---|---|
| `SessionStart` | idle |
| `BeforeAgent`, `AfterTool` | working |
| `Notification` | blocked |
| `AfterAgent` | done |
| `SessionEnd` | clear |

Written from the Gemini CLI hooks reference; not exercised here.
