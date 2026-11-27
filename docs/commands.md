# Command reference

All commands take the pane from `$TMUX_PANE`, else the pane whose shell is an
ancestor of the caller, else the current client's window, unless one is given.

| Command | What it does |
|---|---|
| `hook <Event>` | Claude Code hook entry; reads the hook JSON on stdin |
| `set working\|blocked\|ask\|done\|idle [pane]` | report a state for any agent |
| `clear [pane]` | the agent exited; drop its state, kind and name |
| `seen [window]` | mark a done window as viewed (the hooks call this) |
| `next` | switch to the next blocked window, else ask, else done, oldest wait first, skipping wait and park |
| `hold wait\|park\|clear [window]` | toggle a triage hold |
| `list` | the session > window > pane tree the switcher shows |
| `sync` | pull names and presence from Claude's session registry |
| `needs` | recompute the needs-you count (`@agent_needs`) |
| `progress [print\|clear]` | redraw the terminal progress bar; `print` lists `tty<TAB>value` instead of writing, `clear` hides it |
| `limits` | recompute the usage meter (`@agent_limits`); with `@agent_signal_limits` off, unset it and its `@agent_limit_*` data |
| `statusline [command]` | Claude Code `statusLine` entry: records the usage limits in the JSON on stdin in the background, and runs `command` (else `@agent_signal_statusline_next`) with the same stdin, printing its output and keeping its exit status. With no command it prints nothing |
| `check` | report what is wired on this server and what is missing; exit 1 if broken |
| `install-claude-hooks` | merge the hooks into `~/.claude/settings.json` (needs jq); a symlinked settings file is written through, not replaced |
| `install-claude-statusline` | set `statusLine` in `~/.claude/settings.json` to `agent-signal statusline`, wrapped around the status line you had (needs jq) |
| `uninstall` | reverse everything the entry file set on the server, and restore the `statusLine` the installer replaced, unless it has been edited since |
| `lock-path <window>` | print the lock directory for a window (debugging) |
| `help`, `version` | |

## Claude Code hook mapping

| Claude event                                  | State   |
|-----------------------------------------------|---------|
| `SessionStart` (startup, resume, clear, fork) | idle, and pull the session name from Claude's registry. The `compact` source is ignored: the agent is mid-turn |
| `UserPromptSubmit`, `PreToolUse`, `PostToolUse` | working |
| `PreToolUse` for AskUserQuestion              | ask (plan approval is not mapped here: it arrives as a `PermissionRequest`) |
| `PermissionRequest`, `Notification` permission_prompt | blocked |
| `Notification` elicitation, agent_needs_input | ask |
| `Notification` idle_prompt                    | done, but only if the pane is still marked working (a turn ended with Esc skips `Stop`). Otherwise ignored, since this fires a minute after every finish |
| `Stop` or `StopFailure` with no background tasks | done    |
| `Stop` while a background task is still running | working, until a later `Stop` reports it finished |
| `SessionEnd`                                  | cleared |
| any event from a background job (`CLAUDE_JOB_DIR` set) | ignored: the pane's state belongs to the interactive session |

Hooks are registered `async` so they never delay Claude. Each call is a
handful of tmux commands: on an 18-pane server one event costs about a dozen
tmux client calls, roughly half a second on a slow machine and much less on a
fast one. Updates to the same window are serialised with a lock, since Claude
runs hooks concurrently.

## The usage meter and Claude's status line

Claude Code has one `statusLine` command and sends it the rate-limit
windows, so with `@agent_signal_limits on` that command has to be the
plugin. `install-claude-statusline` rewrites only `statusLine.command`:

```json
"statusLine": { "type": "command", "command": "\"/path/to/bin/agent-signal\" statusline 'your-old-command'", "padding": 2 }
```

Your old command still draws the status line: it gets the same JSON on
stdin, and its output and exit status pass straight through, inside tmux or
out of it. It is run with `sh -c`, so an inline command written in bash-only
syntax belongs in a script of its own. With no old command, nothing is
printed and Claude shows no status line.

The setting as it was, and what replaced it, are kept in
`~/.claude/settings.json.statusline-agent-signal`. `uninstall` puts the
original back only while `statusLine` is still exactly what the installer
wrote. If you have edited it since (the wrapped command, `padding`), or
replaced it, it is yours: `uninstall` leaves it, says so, and leaves the
kept original where it is. Running the installer again is safe on the same
terms: an untouched install is redone from the original, which also
follows a plugin that has moved, and an edited one is refused. A
`settings.json` that does not parse changes nothing. Both commands write
through the file, so a `settings.json` that is a symlink into a dotfiles
repo stays one and keeps its mode.

Run the installer from the copy tpm manages (`~/.tmux/plugins/...`): the
path it writes is its own, and the copy Claude Code keeps for its plugin
moves with each plugin update. Without jq, set the command by hand as
above. Recording itself works without jq.

## Other agents

Any agent that can run a command on lifecycle events can report:

```sh
agent-signal set working|blocked|ask|done [pane-id]
agent-signal clear [pane-id]
```

The pane defaults to `$TMUX_PANE`, which tmux exports to every process in the
pane. If an agent drops it (Claude occasionally runs a hook without it), the
script walks its own parent processes to the pane's shell, and only when that
fails does it use the client's active pane. Set `AGENT_KIND=codex` (or `pi`, `opencode`, ...) in the environment so
the switcher labels it. Nothing needs to know where the plugin is installed:
the entry file publishes the script's path as a server option, so a hook can
always call

```sh
"$(tmux show -gv @agent_signal_command)" set blocked
```

If one agent launches another inside the same pane (Claude running Codex,
say), both report and the child overwrites the parent. Set
`AGENT_SIGNAL_DISABLE=1` on the nested command and its hooks exit quietly
without touching the pane.

Ready-made mappings for Codex CLI, Gemini CLI, Copilot CLI, OpenCode, Pi,
Grok CLI and Antigravity CLI are in [`integrations/`](../integrations/), each
with its event table. They were written from the vendors' documentation and
from [workmux](https://github.com/raine/workmux)'s shipped hooks, and are not
exercised here, so reports and fixes from people who run those agents are
welcome.

## Uninstall

```sh
~/.tmux/plugins/tmux-agent-signal/bin/agent-signal uninstall
```

removes the status-bar fragments, hooks, key bindings and any per-window or
per-pane state from the running server, and restores the `statusLine` that
`install-claude-statusline` replaced. Then drop the plugin line from your
tmux config and delete the `agent-signal` entries from the hooks block in
`~/.claude/settings.json`.

