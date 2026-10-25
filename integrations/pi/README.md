# Pi

Pi extensions are TypeScript modules with lifecycle events. Copy
[`tmux-agent-signal.ts`](tmux-agent-signal.ts) into your Pi extensions
directory.

| Pi event | Word |
|---|---|
| `session_start` | idle |
| `agent_start` | working |
| `ui_prompt_start` | ask (a blocking prompt is waiting on you) |
| `agent_settled` | done, unless the last assistant message was aborted: Pi settles after an interrupted compaction or retry too, and carries on by itself |
| `session_shutdown` | clear |

Written from the Pi extensions reference; the aborted-turn rule comes from
workmux's Pi extension, which its users run. Not exercised here.
