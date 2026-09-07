# GitHub Copilot CLI

Copilot CLI loads hook files from `~/.copilot/hooks/*.json`. Copy
[`hooks.json`](hooks.json) there under any name.

| Copilot event | Word |
|---|---|
| `sessionStart` | idle |
| `userPromptSubmitted`, `postToolUse`, `postToolUseFailure` | working |
| `permissionRequest` | blocked |
| `agentStop` | done |
| `sessionEnd` | clear |

The permission hook prints nothing, which Copilot reads as no opinion, so
your normal approval flow is untouched.

Written from the Copilot CLI hooks reference; not exercised here.
