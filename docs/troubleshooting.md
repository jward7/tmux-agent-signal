# Troubleshooting

- **Nothing changes.** Run `agent-signal check` inside a pane: it says what is
  and is not wired. If everything is ok there, run `agent-signal set blocked`;
  if the tab changes, tmux is fine and the hooks are not firing, so check
  `~/.claude/settings.json` and open `/hooks` in Claude to reload. If even
  `set blocked` does nothing, make sure `AGENT_SIGNAL_DISABLE` is not set in
  that shell; for hooks, `CLAUDE_JOB_DIR` has the same effect.
- **Copy-mode keys or plugin hooks stop working during a Homebrew tmux
  upgrade.** Homebrew unlinks `tmux` from `/usr/local/bin` while it builds.
  Plugins that shell out to `tmux` (tmux-yank, tmux-copycat) fail until it is
  relinked. This plugin looks for the Cellar binary as a fallback, so it keeps
  working until brew deletes the old version, at which point see the next
  item. Wait for brew to finish, or `brew link tmux`.
- **Icons render as boxes or gaps.** Your font lacks ✓ or …. Set
  `@agent_signal_ascii on`, or give each state your own icon.
- **New windows or splits die instantly after a Homebrew tmux upgrade.** The
  new client cannot spawn panes on the old, still-running server. Save with
  resurrect, `tmux kill-server`, start tmux again, and let continuum restore.
- **The badge does not appear with a theme.** Load this plugin after the
  theme. The badge is appended to whatever `window-status-format` is set when
  the plugin loads.
- **A dead pane's glyph lingers** in the fleet summary on tmux 3.4 (Ubuntu
  24.04). That tmux only notices a pane has died on its next child exit, so
  the glyph goes on the next hook or `agent-signal summary`. tmux 3.5 and
  later fixed this.
- **`next` says nothing needs you** while a tab is orange or pink: the
  window is on `wait` or `park`. `prefix + W` / `prefix + P` clears it.
