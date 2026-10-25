# How it compares

All of these are good projects under active development, so this is a
snapshot as of **2026-09-07**, agent rows re-checked **2026-10-25**.
[workmux](https://github.com/raine/workmux) is left out because it is a
worktree manager with a status layer, not a status plugin, but several of
this plugin's integrations were corrected against its. tmux-agent-state is the closest relative:
the same hook-driven, no-daemon design, without the triage, switcher and
summary layers. 🟢 has it, 🟡 partial or optional, 🔴 does not,
▫️ not applicable. Corrections welcome.

| | tmux-agent-signal | [tmux-agent-state](https://github.com/cburmeister/tmux-agent-state) | [samleeney/tmux-agent-status](https://github.com/samleeney/tmux-agent-status) | [gentle-agent-state](https://github.com/Gentleman-Programming/gentle-agent-state) | [RatulMaharaj/tmux-agent-status](https://github.com/RatulMaharaj/tmux-agent-status) | [herdr](https://github.com/herdrdev/herdr) |
|---|---|---|---|---|---|---|
| Stays inside tmux | 🟢 | 🟢 | 🟢 | 🟢 also Zellij, Ghostty | 🟢 | 🔴 replaces tmux |
| State source | 🟢 hooks | 🟢 hooks | 🟢 hooks | 🟢 hooks | 🔴 polls `ps` and screen text | 🟡 hooks for some agents, screen heuristics for Claude and Codex |
| No daemon or polling | 🟢 | 🟢 | 🔴 collector daemon | 🟢 | 🔴 3 s poller | ▫️ is the server |
| Works with no hooks installed | 🔴 | 🔴 | 🔴 | 🔴 | 🟢 | 🟢 |
| Per-window badge | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | ▫️ sidebar |
| Tab colour per state | 🟢 | 🟢 | 🔴 | 🔴 marker only | 🟢 | ▫️ |
| Question vs permission distinguished | 🟢 | 🔴 | 🟡 in an open PR | 🔴 | 🔴 | 🟢 |
| Done clears when viewed | 🟢 | 🟢 | 🟢 | 🔴 | 🟢 | 🟢 |
| Jump to next needing you | 🟢 | 🟢 | 🟢 | 🔴 | 🔴 | 🟢 |
| Wait / park triage | 🟢 | 🔴 | 🟢 | 🔴 | 🔴 | 🔴 |
| Switcher with close actions | 🟢 fzf popup | 🔴 | 🟢 sidebar + popup | 🔴 | 🔴 | 🟢 |
| Fleet summary in status bar | 🟢 | 🔴 | 🟢 | 🔴 | 🟡 badges only | 🟢 |
| Sounds | 🟢 | 🟡 bell; bring your own notifier | 🟢 | 🟢 | 🟢 | 🟢 |
| Background task awareness | 🟢 | 🔴 | 🟢 | 🔴 | 🔴 | ▫️ |
| Claude Code | 🟢 plugin or hooks | 🟢 plugin install | 🟢 | 🟢 | 🟢 | 🟢 |
| Codex CLI | 🟡 from docs | 🟡 done only | 🟢 | 🟢 | 🟡 presence only | 🟢 |
| Pi / OpenCode | 🟡 from docs / 🟡 from docs | 🟡 no confirmation prompts / 🟢 | 🔴 / 🔴 | 🟢 / 🟢 | 🔴 / 🟡 presence only | 🟢 |
| Gemini CLI / Copilot CLI | 🟡 from docs / 🟡 from docs | 🟢 / 🟢 | 🔴 / 🟡 custom status file | 🔴 | 🔴 | 🔴 |
| Grok CLI / Antigravity CLI | 🟡 from workmux's hooks / 🟡 from workmux's hooks | 🔴 | 🔴 | 🔴 | 🔴 | 🟢 / 🔴 |
| Agent-to-agent API | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 | 🟢 socket API |
| Survives lid close / restart without resume | 🔴 use resurrect | 🔴 | 🔴 | 🔴 | 🔴 | 🟢 |
| Tests in repo | 🟢 | 🟢 | 🟢 | 🟢 | 🔴 | 🟢 |
| Licence | MIT | MIT | none stated | MIT | MIT | Apache-2.0 |

If you want detection with nothing installed in the agent, or agents that talk
to each other, herdr is the right tool and this plugin is not trying to be it.
If you want to stay in your tmux setup with hooks doing the work, this plugin
is the smallest option that still covers triage and navigation.
