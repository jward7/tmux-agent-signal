# Changelog

## 0.3.0 (2026-09-07)

- Installable as a Claude Code plugin: `/plugin marketplace add
  jward7/tmux-agent-signal`, then `/plugin install tmux-agent-signal@jward7`.
- The script's path is published as `@agent_signal_command`, so other
  agents' hook files never hard-code a plugin directory.
- A hook that fires before tmux has sourced the entry file wires the server
  up itself instead of being dropped.
- `check` subcommand: reports what is wired, what is missing, which windows
  carry an unmended format override, and which optional tools are present.
- `@agent_signal_alert_command`: run your own command on a state transition,
  with tmux formats expanded and the state in the environment.
- A per-window `window-status-format` set by a theme gets the badge woven in
  on that window's next event.
- `@agent_signal_tab_colour` gains `needs` (colour the tab only when the
  window needs you) alongside `all` and `off`.
- Integrations for Codex CLI, Gemini CLI, Copilot CLI, OpenCode and Pi,
  written from the vendors' docs.
- Plan approval no longer reports twice: only AskUserQuestion maps to ask,
  since ExitPlanMode arrives as a PermissionRequest.

## 0.2.1 (2026-09-07)

- The per-window lock is keyed on the tmux server socket as well as the
  window id, so two servers on one machine cannot contend for each other's
  locks or leave stale ones behind. `agent-signal lock-path <window>` prints
  the path for debugging.
- Tests: one file per feature, each on its own server, run in parallel by a
  new runner (`sh test/run.sh`, `-j N`, feature names to filter).

## 0.2.0 (2026-09-07)

Hardening from a full review; no new features.

- Updates to a window are serialised with a per-window lock, so concurrent
  Claude hooks cannot overwrite each other.
- The idle-reminder hook exits 0 when there is nothing to rescue.
- `next` handles session names containing spaces.
- A user's or theme's per-window `window-status-style` is never removed
  unless the plugin set it.
- The switcher survives an empty window name and aligns columns with
  multibyte icons.
- `@agent_needs` counts windows, as documented, not panes.
- `seen` acts on the window the hook fired for, so a second attached client
  cannot clear the wrong window.
- Per-event cost roughly halved: one read for all pane states, batched
  writes, one awk for the summary, no temp file.
- The no-jq fallback reads spaced JSON and the background task array.
- Installer quotes the plugin path, keeps the first backup, registers
  StopFailure, and cleans up on failure.
- Style options are validated before reaching tmux.
- `uninstall` subcommand; existing key bindings are never clobbered.
- `help` subcommand and real argument errors.
- Entry file and switcher no longer crash when tmux is off PATH.
- Tests: 83 checks, polling instead of sleeps, coverage for every item above.
- CI lints the demo script and cancels superseded runs.

## 0.1.0 (2026-09-07)

Initial release.

- Per-window working / blocked / ask / done badges and tab colours, driven by
  agent lifecycle hooks and stored in tmux user options. No daemon, no polling.
- Claude Code hooks included, with an installer that merges into
  `~/.claude/settings.json`. Generic `set` entry for any other agent.
- Sounds, optional desktop banner and tmux bell when a hidden window needs you.
- `next` key: jump to the next blocked, ask, or done window.
- Wait and park triage holds.
- fzf switcher popup over sessions, windows and panes, with close actions.
- Fleet summary in status-right: one glyph plus window index per agent.
- Optional outer-terminal title with the needs-you count.
- ASCII icon preset.
- End-to-end tests against an isolated tmux server; shellcheck in CI.
