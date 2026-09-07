// tmux-agent-signal for OpenCode. Copy into ~/.config/opencode/plugins/.
// Reports one word per lifecycle event to the tmux plugin; every call is
// fire-and-forget so a broken indicator can never block the agent.
export const TmuxAgentSignal = async ({ $ }) => {
  const report = async (word) => {
    if (!process.env.TMUX) return
    try {
      await $`sh -c ${'AGENT_KIND=opencode exec "$(tmux show -gv @agent_signal_command)" ' + (word === 'clear' ? 'clear' : 'set ' + word)}`.quiet().nothrow()
    } catch {}
  }
  const children = new Set()          // subagent sessions, whose lifecycle is not the window's
  const prompted = new Set()          // user message ids already counted as a prompt
  return {
    event: async ({ event }) => {
      const p = event.properties ?? {}
      switch (event.type) {
        case 'session.created':
          if (p.info?.parentID) { children.add(p.info.id); return }
          return report('idle')
        case 'message.updated': {
          const m = p.info ?? {}
          if (m.role !== 'user' || children.has(m.sessionID) || prompted.has(m.id)) return
          prompted.add(m.id); if (prompted.size > 200) prompted.delete(prompted.values().next().value)
          return report('working')
        }
        case 'tool.execute.after':
        case 'permission.replied':
          return report('working')
        case 'permission.asked':
          return report('blocked')
        case 'session.error':
          if (children.has(p.sessionID)) return
          return report('blocked')
        case 'session.idle':
          if (children.has(p.sessionID)) return
          return report('done')
        case 'session.deleted':
          if (children.delete(p.info?.id)) return
          return report('clear')
      }
    },
  }
}
