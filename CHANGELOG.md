# Changelog

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
