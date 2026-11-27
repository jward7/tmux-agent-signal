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

**Writes only what changed.** tmux repaints every attached client whenever an
option is set, even to the value it already has. So each step reads what is
there first (the pane's state, the window's badge and tab style, the
needs-you count, the usage meter) and writes only what differs. A tool call
by an agent that is already working, the commonest event by far, writes
nothing. Anything found wrong is still put right: a tab style a theme
overwrote comes back on the window's next event.

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

## Usage meter

Opt-in (`@agent_signal_limits on`). The numbers come from what the agents
already write locally. The plugin makes no network call and reads no
credential.

```
Claude statusLine ──> agent-signal statusline ──> your previous statusLine command (same stdin)
                                               └─> in the background: @agent_limit_claude_<5h|7d>_used/_reset, _at
                                                   then rebuild @agent_limits
Codex Stop hook ──> agent-signal set done ──> tail of the newest rollout log ──> @agent_limit_codex_...
any agent event ──> rebuild @agent_limits
status-right: #{@agent_limits}, read natively
```

**Claude Code** pipes a JSON object to its `statusLine` command after each
assistant message. For Pro, Max and Ultra plans it carries
`rate_limits.five_hour` and `rate_limits.seven_day`, each with
`used_percentage` (0 to 100) and `resets_at` (epoch seconds). The object is
absent until the session's first API response, either window can be
missing, and Claude drops a window once its reset passes. A payload records
the windows it has and leaves the others as they were. A window whose reset
has already passed is not recorded: an idle session can still be holding one. Only windows under
`rate_limits` count. Recording runs in the background, so your own status
line command starts at once and never waits for it.

**Codex** writes each session to
`${CODEX_HOME:-~/.codex}/sessions/YYYY/MM/DD/rollout-*.jsonl`. Its
`token_count` events carry `rate_limits.primary` and `.secondary`, each
with `used_percent`, `window_minutes` and `resets_at`. When a Codex turn
ends (`set done` with `AGENT_KIND=codex`) the plugin reads the last such
record in the last 100 lines of the most recently written log. Windows are
told apart by `window_minutes` (300 is the 5-hour one, 10080 the weekly,
give or take a few minutes of rounding), not by position, and any other
length is ignored. An older Codex wrote `resets_in_seconds` instead, which
is counted from the moment it is read. A record with neither field keeps
the reset already stored while that is still to come; otherwise no reset is
stored, and that window has no pace. If the tail holds records for more
than one `limit_id` (a model metered apart from the main allowance), the
one called `codex`, or with no id, is read.

Every session reports what it last saw, so an idle one can be behind the
others. For ten minutes after a record is stored, a report is ignored when
its window resets earlier, or when it is the same window with less used:
within one window usage only grows. After ten minutes anything is taken, so
a real drop (the provider resets usage, a plan changes) shows on the next
report, and a stale figure that slips through is corrected by the next
report from a session that is working. An agent's two windows share one
record time, which is read once before either is written, so the second
window is judged by the same clock as the first. Each record is written in
a single tmux command, so two sessions reporting at once cannot leave one
window's usage beside another's reset. Numbers that have not changed are
not written again, which is why the record time can be up to five minutes
behind the last report.

**No polling.** `@agent_limits` is worked out when a window is recorded and
on every agent event the plugin already handles, in one tmux call and one
awk, and written only when the figure has changed. Pace and staleness depend on the clock, so they only advance at
those moments. With every agent idle the meter is as old as the last event,
which is also when the allowance is not being spent.

**If a network source is ever added** (the agents' undocumented usage
endpoints would give numbers between events), it has to keep to the rules
the existing tools in this space follow:

- credentials are read-only: never refresh, rotate or write a token, and
  show stale data instead;
- a bearer token never goes in argv: `curl --config -` on stdin, never `-H`
  on the command line;
- after an HTTP 429, back off five minutes and keep the last good value,
  marked stale;
- an atomic cache and `flock`, so several tmux clients do not repeat the
  request.

`agent-signal sync` reads Claude Code's own session registry
(`~/.claude/sessions/*.json`, which records each session's tmux pane and
display name) to label panes. It runs on `SessionStart`, when the plugin
loads, and when the switcher opens.
