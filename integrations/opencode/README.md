# OpenCode

OpenCode loads JavaScript plugins from `~/.config/opencode/plugins/` (or
`.opencode/plugins/` per project). Copy [`tmux-agent-signal.js`](tmux-agent-signal.js)
there and restart OpenCode.

| OpenCode event | Word |
|---|---|
| `session.created` | idle |
| `message.updated` (a user message), `tool.execute.after`, `permission.replied` | working |
| `permission.asked`, `session.error` | blocked |
| `session.idle` | done |
| `session.deleted` | clear |

Subagent sessions (created with a parent) are ignored except for
`permission.asked`, so a child finishing does not mark the window done
while the parent is still working.

Written from the OpenCode plugin reference; not exercised here.
