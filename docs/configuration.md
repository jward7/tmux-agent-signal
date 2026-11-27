# Configuration

Set any of these in `tmux.conf` before the plugin loads.

The badges, their colours and the window-tab format are not options: the
plugin has one look. What it publishes for your own formats:

- `@agent_needs` (global): how many windows are blocked or asking, unset
  when none. For example, in `status-left`:
  `#{?@agent_needs,#[fg=black#,bg=colour208] #{@agent_needs} need you #[default],}`
- `@agent_name` (pane): the agent's session name, from Claude's registry.
- `@agent_limits` (global): the usage meter, only with `@agent_signal_limits
  on`. See [Usage meter](#usage-meter).

```tmux
set -g @agent_signal_tab_colour all       # all: colour the tab for every state that has one
                                          # needs: colour it only when the window needs you (blocked, ask)
                                          # off: badge only, never restyle the tab

# Outer terminal title
set -g @agent_signal_title off            # on = set-titles with the needs-you count
set -g @agent_signal_title_format '#{?@agent_needs,[#{@agent_needs} need you] ,}#S:#W'

# Terminal progress bar (OSC 9;4), the bar along the top of the terminal tab
set -g @agent_signal_progress window      # window: the window on screen; server: every window; off
# Terminals that get it, as an extended regex on #{client_termtype} (tmux 3.3+).
# Anything else, including a terminal that does not say what it is, gets nothing.
set -g @agent_signal_progress_terminals '^(iTerm2 (3\.([6-9]|[1-9][0-9])|[4-9])|WezTerm|ghostty)'

set -g @agent_signal_confirm_close on     # off = switcher closes without asking

# Sounds (macOS system sound names, or a file path; "off" to silence one)
set -g @agent_signal_sound on
set -g @agent_signal_sound_blocked Ping
set -g @agent_signal_sound_ask Ping
set -g @agent_signal_sound_done Glass

set -g @agent_signal_notify off           # on = desktop banner too (terminal-notifier, osascript, notify-send)

# Or run anything you like when a window changes state. Runs in the background,
# only on a transition (blocked -> blocked stays quiet). tmux formats expand
# against the window; the shell gets AGENT_SIGNAL_STATE, AGENT_SIGNAL_PREV,
# AGENT_SIGNAL_WINDOW and AGENT_SIGNAL_PANE.
set -g @agent_signal_alert_command 'terminal-notifier -title "#{session_name}:#{window_name}" -message "agent is $AGENT_SIGNAL_STATE" -execute "tmux switch-client -t $AGENT_SIGNAL_WINDOW"'
set -g @agent_signal_alert_states 'blocked ask done'
set -g @agent_signal_bell off             # on = also ring tmux's bell in the pane (monitor-bell, works over SSH)

# Keys ("" disables a binding)
set -g @agent_signal_key_next N
set -g @agent_signal_key_switcher A
set -g @agent_signal_key_wait W
set -g @agent_signal_key_park P
```

## Usage meter

Off by default. Switched on, the plugin records how much of each agent's
subscription allowance is used and publishes one option for your own status
line. It never places it for you:

```tmux
set -g @agent_signal_limits on               # on = record limits and publish @agent_limits
set -g @agent_signal_limits_show remaining   # remaining | used
set -g @agent_signal_limits_pace 10          # points behind pace before colouring; 0 = never colour for pace

set -g status-right '#{@agent_limits} %H:%M'
```

Claude Code reports through its status line, so point that at the plugin
once (`agent-signal install-claude-statusline`, which keeps the status line
you had). Codex needs nothing beyond its [hooks](../integrations/codex/):
its session log is read as each turn ends.

`@agent_limits` reads `C 62% X 40%`: Claude has 62% of its 5-hour window
left, Codex 40%. The weekly figure joins as `w30%` when it has less left
than the 5-hour one, when it is the one flagged, or when it is the only
window the agent reports (`C w64%`). An agent with nothing recorded is not
shown, and with no agent to show the option is unset.

| Looks | Means |
|---|---|
| plain | on pace |
| orange | 90% used or more, or over pace: what is left trails an even burn-down of the window by more than `@agent_signal_limits_pace` points. With 2h15m of the 5 hours to go, 45% should be left; 30% left is over pace, 40% is not |
| red | 100% used |
| dim | that agent has not reported for six hours |

A window whose reset time has passed is dropped: the allowance is new and
the old number means nothing.

Nothing runs on redraw and there is no timer, so the meter moves when an
agent reports or any agent event fires, and not in between. With every
agent idle the last value stays put. `agent-signal limits` recomputes it on
demand.

Switched off again, the meter and its data are unset when the plugin next
loads (reloading `tmux.conf` does it) or when you run `agent-signal limits`.

There is one set of numbers per agent. Two Claude accounts on one tmux
server (`CLAUDE_CONFIG_DIR`) would overwrite each other, and the installer
only knows `~/.claude/settings.json`.

What `@agent_limits` is built from is published too, all global, for a
format of your own:

- `@agent_limit_<agent>_<window>_used`: integer 0 to 100, for `claude` or
  `codex` and `5h` or `7d`.
- `@agent_limit_<agent>_<window>_reset`: epoch seconds when that window
  resets. Unset when the agent did not say. Check it before trusting
  `_used`: a recorded window stays until a newer one replaces it.
- `@agent_limit_<agent>_at`: epoch seconds when that agent last reported.

If Claude's status line is set by hand, `@agent_signal_statusline_next`
names the command `agent-signal statusline` runs after recording, with the
same stdin. The installer does not need it: it passes your old command as an
argument.
