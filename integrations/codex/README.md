# Codex CLI

Codex has lifecycle hooks in Claude Code's format, behind a feature flag.
Enable them in `${CODEX_HOME:-$HOME/.codex}/config.toml`:

```toml
[features]
hooks = true
```

then merge [`hooks.json`](hooks.json) into `${CODEX_HOME:-$HOME/.codex}/hooks.json`
(copy it there if you have none). Start a new Codex session.

| Codex event | Word |
|---|---|
| `SessionStart` (startup, resume, clear) | idle |
| `UserPromptSubmit`, `PostToolUse` | working |
| `SubagentStart`, `SubagentStop` | working: a child finishing is not the turn finishing |
| `PermissionRequest` | blocked |
| `Stop` | done |

Codex's `SessionStart` is bound to the first turn rather than to launch, so
the pane is labelled when the first prompt goes in. Codex does not fire a
`SessionEnd`; the state is dropped when the pane closes.

If your Codex predates hooks, the older `notify` setting still gives you done:

```toml
notify = ["sh", "-c", "AGENT_KIND=codex \"$(tmux show -gv @agent_signal_command)\" set done"]
```

Written from the Codex hooks reference and workmux's shipped Codex hooks,
which its users run; not exercised here.
