# Codex CLI

Codex's only outward lifecycle event is `notify` in `~/.codex/config.toml`,
run when a turn completes with a JSON payload as its last argument. So the
tab can show done, and nothing else. Add:

```toml
notify = ["sh", "-c", "AGENT_KIND=codex \"$(tmux show -gv @agent_signal_command)\" set done"]
```

Outside tmux the command fails quietly and Codex never notices. Codex's own
in-terminal approval alert still works alongside this.

Written from the Codex configuration reference; not exercised here.
