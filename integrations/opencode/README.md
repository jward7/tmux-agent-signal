# OpenCode

Two plugin APIs exist. Pick the one your OpenCode loads.

**Plugin API v2 (terminal UI plugins).** Copy the
[`v2/tmux-agent-signal/`](v2/tmux-agent-signal/) directory to
`~/.config/opencode/plugins/tmux-agent-signal/` and restart OpenCode.
Headless `opencode run` is not tracked.

| OpenCode event | Word |
|---|---|
| plugin loads | idle |
| `session.execution.started` | working |
| `permission.asked`, `form.created` | blocked |
| `permission.replied`, `form.replied`, `form.cancelled`, `session.execution.*` finishing | recomputed |
| plugin unloads | clear |

**Plugin API v1.** Copy [`tmux-agent-signal.js`](tmux-agent-signal.js) into
`~/.config/opencode/plugins/` (or `.opencode/plugins/` per project).

| OpenCode event | Word |
|---|---|
| `session.created` (no parent) | idle |
| `message.updated` (a user message) | working |
| `permission.asked` | blocked |
| `question.asked` | ask |
| `permission.replied`, `question.replied`, `session.idle` | recomputed |
| `session.deleted` (last session) | clear |

In both, the word is computed over every session the process serves, root and
subagents alike: a pending permission anywhere is blocked, a pending question
is ask, otherwise a running session is working, otherwise done. `session.error`
is deliberately not a wait: an Esc or an error is followed by `session.idle`,
and a context overflow by OpenCode's own compaction. Reports are serialised so
an older one never lands after a newer one. A subagent finishing while its parent runs
changes nothing. The plugins stay silent unless `TMUX_PANE` is set, because
OpenCode's server can be shared by several terminals and only a process that
knows its own pane may speak for it.

Written from the OpenCode plugin references and workmux's OpenCode plugins,
which its users run; not exercised here.
