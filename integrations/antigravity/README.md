# Antigravity CLI (`agy`)

Antigravity reads named hook groups from `~/.gemini/config/hooks.json`. Merge
[`hooks.json`](hooks.json) into it (add the `tmux-agent-signal` group next to
any you already have) and restart running `agy` sessions: hook configuration
is loaded at session start.

| Antigravity event | Word |
|---|---|
| `PreInvocation` | working |
| `Stop` | done |

Antigravity expects a JSON reply from every hook and blocks the tool call
otherwise, so each command swallows its own output and prints `{}`. There is
no permission event, so blocked is never shown; the pane is labelled when the
agent first runs, not at launch.

Written from workmux's shipped Antigravity hooks, which its users run; not
exercised here.
