# Integrations

The plugin's whole interface for an agent is one command with one word:

```sh
"$(tmux show -gv @agent_signal_command)" set working|blocked|ask|done|idle
"$(tmux show -gv @agent_signal_command)" clear
```

The entry file publishes the script's location as `@agent_signal_command`, so
nothing here hard-codes a path. Set `AGENT_KIND=<agent>` so the switcher and
the status-right summary label the pane. The script exits 0 and prints
nothing, so a broken indicator can never block an agent.

| Agent | Integration | working | blocked | ask | done | Status |
|---|---|:-:|:-:|:-:|:-:|---|
| Claude Code | hooks (built in, see the main README) | yes | yes | yes | yes | exercised daily |
| [Codex CLI](codex/) | `notify` in `config.toml` | | | | yes | from the docs, not exercised here |
| [Gemini CLI](gemini/) | hooks in `settings.json` | yes | yes | | yes | from the docs, not exercised here |
| [Copilot CLI](copilot/) | hooks file | yes | yes | | yes | from the docs, not exercised here |
| [OpenCode](opencode/) | plugin | yes | yes | | yes | from the docs, not exercised here |
| [Pi](pi/) | extension | yes | | yes | yes | from the docs, not exercised here |

"From the docs" means the mapping was written against the vendor's published
hook or plugin reference, in September 2026, by someone who does not run that
agent. If you do, a report that it works, or a fix, is the most useful pull
request this repo can get. An agent that fires no event for a state simply
never shows that state; the tab is honest about what the agent can say.
