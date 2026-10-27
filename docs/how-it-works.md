# How it works

```
Claude hook ──> agent-signal hook Stop ──> tmux set -p @agent_pane_state done
                                        └─> recompute window: @agent_state, @agent_since,
                                            @agent_icon, @agent_fg, window-status-style
                                        └─> recompute @agent_needs
                                        └─> not on screen? play sound
window-status-format: #{@agent_icon} in #{@agent_fg}, then #I:#W
pane-border-style: your style, then fg=orange/pink/green by #{@agent_pane_state}
after-select-window / client-focus-in hook ──> agent-signal seen <window> ──> done -> idle
```

Claude runs hooks concurrently, so each update takes a lock keyed on the
server socket and window id (a `mkdir` in `$TMPDIR`, reclaimed if a holder
was killed) before reading and rewriting the window's state.

**Progress bar.** After every refresh and every `seen`, `refresh_progress`
lists the clients and, for each whose `#{client_termtype}` matches
`@agent_signal_progress_terminals`, writes `ESC ] 9 ; 4 ; state ; percent BEL`
straight to its tty, so `allow-passthrough` is not involved. The value comes
from the agent panes of the window that client shows: blocked `2;100`
(error), ask `4;100` (warning), all working `3;0` (indeterminate), some
finished `1;<finished share>`, done and unseen `1;100`, otherwise `0;0`
(hidden). The allowlist exists because OSC 9 is a desktop notification in
older iTerm2 and in other terminals, and unknown sequences may be printed.

`@agent_since` records when a window's aggregate state last changed, and
`next` uses it to serve the longest wait first within a tier.

Per-pane state lets several agents share a window. The window shows the most
urgent pane. Pane state is stored under `@agent_pane_state`, a different name
from the window's `@agent_state`, because pane options inherit from the window
in tmux formats and would otherwise read back the aggregate.

The plugin sets the global `window-status-format` and
`window-status-current-format` when it loads, keeping what was there in
`@agent_saved_<option>` for `uninstall`, and appends a conditional to
`pane-border-style` and `pane-active-border-style` that colours a pane's
border by its own `@agent_pane_state`. tmux expands border styles against
the pane that owns the border cell, so no per-pane option is needed and it
works from tmux 3.2. tmux credits a shared border to the first adjacent pane
in its list, preferring the active one, so this is only dependable with two
panes, where each pane owns half the shared line. With more panes `next`
selects the pane instead. A theme that sets a format on an individual window gets
the badge put in front of that window's value on its next event. It only ever touches a window's `window-status-style` when it set
it, tracked with `@agent_tab_owned`, so a style you or a theme put on a window
survives. Key bindings are skipped, with a message, when the key is already
bound to something else.

`agent-signal sync` reads Claude Code's own session registry
(`~/.claude/sessions/*.json`, which records each session's tmux pane and
display name) to label panes. It runs on `SessionStart`, when the plugin
loads, and when the switcher opens.
