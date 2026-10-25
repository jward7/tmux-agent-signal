# Grok CLI

Grok discovers hook files in `${GROK_HOME:-$HOME/.grok}/hooks/*.json`, in
Claude Code's format. Copy [`hooks.json`](hooks.json) there under any name
and start a new Grok session.

| Grok event | Word |
|---|---|
| `SessionStart` | idle |
| `UserPromptSubmit`, `PostToolUse` | working |
| `Notification` | blocked |
| `Stop` | done |
| `SessionEnd` | clear |

Not every Grok permission prompt emits a `Notification`, so some waits stay
shown as working until you answer them.

Written from workmux's shipped Grok hooks, which its users run; not
exercised here.
