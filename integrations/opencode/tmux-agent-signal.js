// tmux-agent-signal for OpenCode (plugin API v1). Copy into
// ~/.config/opencode/plugins/. Every call is fire-and-forget so a broken
// indicator can never block the agent.
//
// The window's word is derived from the whole family of sessions this
// process serves, the way workmux's OpenCode plugin does it: a pending
// permission anywhere is blocked, otherwise a running session is working,
// otherwise done. A child finishing while its parent runs changes nothing.
export const TmuxAgentSignal = async ({ $ }) => {
  // OpenCode's server can outlive and be shared by several terminals; only a
  // process that knows its own pane may speak for it.
  if (!process.env.TMUX || !process.env.TMUX_PANE) return {}
  const report = async (word) => {
    try {
      await $`sh -c ${'AGENT_KIND=opencode exec "$(tmux show -gv @agent_signal_command)" ' + (word === 'clear' ? 'clear' : 'set ' + word)}`.quiet().nothrow()
    } catch {}
  }
  const sessions = new Map()          // id -> { running, pending: Set<requestID>, errored }
  const state = (id) => { let s = sessions.get(id); if (!s) { s = { running: false, pending: new Set(), errored: false }; sessions.set(id, s) } return s }
  let reported
  const publish = async () => {
    let word = 'done'
    for (const s of sessions.values()) {
      if (s.pending.size || s.errored) { word = 'blocked'; break }
      if (s.running) word = 'working'
    }
    if (word === 'done' && reported === undefined) return   // nothing has run yet
    if (word === reported) return
    reported = word
    await report(word)
  }
  return {
    event: async ({ event }) => {
      const p = event.properties ?? {}
      switch (event.type) {
        case 'session.created':
          state(p.info?.id)
          if (!p.info?.parentID) await report('idle')
          return
        case 'message.updated': {
          const m = p.info ?? {}
          if (m.role !== 'user') return
          const s = state(m.sessionID); s.running = true; s.errored = false
          return publish()
        }
        case 'permission.asked':
          state(p.sessionID).pending.add(p.id)
          return publish()
        case 'permission.replied':
          state(p.sessionID).pending.delete(p.requestID)
          return publish()
        case 'session.error':
          state(p.sessionID).errored = true
          return publish()
        case 'session.idle': {
          const s = state(p.sessionID); s.running = false; s.pending.clear(); s.errored = false
          return publish()
        }
        case 'session.deleted':
          sessions.delete(p.info?.id)
          if (sessions.size === 0) { reported = undefined; return report('clear') }
          return publish()
      }
    },
  }
}
