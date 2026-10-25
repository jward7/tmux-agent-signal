# Recommended setup

These are independent of the plugin but make the whole "many agents in tmux"
workflow hold together.

**Resume agents after a tmux restart.**
[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) and
[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) bring your
layout back, but a Claude pane comes back as a dead shell with the old
transcript painted in.
[tmux-assistant-resurrect](https://github.com/timvw/tmux-assistant-resurrect)
records each agent's session ID at save time and relaunches it with
`claude --resume <id>` on restore. It also supports Codex, Pi, Cursor,
Copilot, OpenCode and Grok. Needs `jq`.

```tmux
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'timvw/tmux-assistant-resurrect'
set -g @continuum-restore 'on'
```

Window state is not saved by resurrect. After a restore, badges reappear as
each agent's hooks fire again.

**Name your Claude sessions.** Claude Code sessions can message each other by
name (`/list-agents`, `SendMessage`). Derived names like `trade-39` are hard to
tell apart. Start sessions with `claude --name <repo>/<branch>` or `/rename`.
The plugin shows these names in the switcher. A shell function that does this
automatically:

```zsh
claude() {
  case " $* " in
    *" -n "*|*" --name "*|*" -r "*|*" --resume"*|*" -c "*|*" --continue "*) command claude "$@" ;;
    *) local root branch name
       if root=$(git rev-parse --show-toplevel 2>/dev/null); then
         branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); name="${root:t}"
         [ -n "$branch" ] && [ "$branch" != main ] && [ "$branch" != master ] && name="$name/$branch"
       else name="${PWD:t}"; fi
       command claude --name "$name" "$@" ;;
  esac
}
```

**tmux settings Claude Code wants** (from its terminal docs):

```tmux
set -g allow-passthrough on          # desktop notifications and progress reach the outer terminal
set -s extended-keys on              # Shift+Enter
set -as terminal-features 'xterm*:extkeys'
set -g focus-events on
```

**Plugin list in an `if-shell`-sourced file.** tpm only follows plain
`source` lines when scanning for `@plugin`. If your local config is loaded via
`if-shell`, declare plugins with the option tpm reads from the server instead:

```tmux
set -g @tpm_plugins '           \
  tmux-plugins/tpm              \
  tmux-plugins/tmux-resurrect   \
  tmux-plugins/tmux-continuum   \
  timvw/tmux-assistant-resurrect \
  jward7/tmux-agent-signal      \
'
run -b '~/.tmux/plugins/tpm/tpm'
```

**Sounds over SSH.** Sounds play on the machine running tmux. For a remote
tmux, turn on `@agent_signal_bell` and let your terminal handle the bell, or
`@agent_signal_notify` with an OSC-aware terminal and `allow-passthrough`.
