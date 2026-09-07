# Pi

Pi extensions are TypeScript modules with lifecycle events. Copy
[`tmux-agent-signal.ts`](tmux-agent-signal.ts) into your Pi extensions
directory.

| Pi event | Word |
|---|---|
| `session_start` | idle |
| `agent_start` | working |
| `ui_prompt_start` | ask (a blocking prompt is waiting on you) |
| `agent_settled` | done (Pi will not continue on its own) |
| `session_shutdown` | clear |

Written from the Pi extensions reference; not exercised here.
