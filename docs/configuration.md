# Configuration

Set any of these in `tmux.conf` before the plugin loads.

The badges, their colours and the window-tab format are not options: the
plugin has one look. What it publishes for your own formats:

- `@agent_needs` (global): how many windows are blocked or asking, unset
  when none. For example, in `status-left`:
  `#{?@agent_needs,#[fg=black#,bg=colour208] #{@agent_needs} need you #[default],}`
- `@agent_name` (pane): the agent's session name, from Claude's registry.

```tmux
set -g @agent_signal_tab_colour all       # all: colour the tab for every state that has one
                                          # needs: colour it only when the window needs you (blocked, ask)
                                          # off: badge only, never restyle the tab

# Outer terminal title
set -g @agent_signal_title off            # on = set-titles with the needs-you count
set -g @agent_signal_title_format '#{?@agent_needs,[#{@agent_needs} need you] ,}#S:#W'

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
