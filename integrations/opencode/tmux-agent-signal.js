// tmux-agent-signal for OpenCode (plugin API v1). Copy into
// ~/.config/opencode/plugins/. Every call is fire-and-forget so a broken
// indicator can never block the agent.
//
// The window's word is derived from the whole family of sessions this
// process serves, the way workmux's OpenCode plugin does it: a pending
// permission or question anywhere is a wait, otherwise a running session is
// working, otherwise done. A child finishing while its parent runs changes
// nothing.
export const TmuxAgentSignal = async ({ $ }) => {
  // OpenCode's server can outlive and be shared by several terminals; only a
  // process that knows its own pane may speak for it.
  if (!process.env.TMUX || !process.env.TMUX_PANE) return {}
  // Reports are serialised so an older one can never land after a newer one.
  let queue = Promise.resolve()
  const report = (word) => {
    queue = queue.then(async () => {
      try {
        await $`sh -c ${'AGENT_KIND=opencode exec "$(tmux show -gv @agent_signal_command)" ' + (word === 'clear' ? 'clear' : 'set ' + word)}`.quiet().nothrow()
      } catch {}
    })
    return queue
  }
  const sessions = new Map()          // id -> { running, blocked: Set<id>, asked: Set<id> }
  const state = (id) => { let s = sessions.get(id); if (!s) { s = { running: false, blocked: new Set(), asked: new Set() }; sessions.set(id, s) } return s }
  // OpenCode re-publishes a user message after the turn (summary written), so
  // a message id counts as a prompt once only.
  const prompted = new Set()
  let reported
  const publish = () => {
    let word = 'done'
    for (const s of sessions.values()) {
      if (s.blocked.size) { word = 'blocked'; break }
      if (s.asked.size) word = 'ask'
      else if (s.running && word === 'done') word = 'working'
    }
    if (word === 'done' && reported === undefined) return   // nothing has run yet
    if (word === reported) return
    reported = word
    return report(word)
  }
  return {
    event: async ({ event }) => {
      const p = event.properties ?? {}
      switch (event.type) {
        case 'session.created':
          state(p.info?.id)
          if (!p.info?.parentID && reported === undefined) return report('idle')
          return
        case 'message.updated': {
          const m = p.info ?? {}
          if (m.role !== 'user' || prompted.has(m.id)) return
          prompted.add(m.id); if (prompted.size > 200) prompted.delete(prompted.values().next().value)
          state(m.sessionID).running = true
          return publish()
        }
        case 'permission.asked':
          state(p.sessionID).blocked.add(p.id)
          return publish()
        case 'permission.replied':
          state(p.sessionID).blocked.delete(p.requestID)
          return publish()
        case 'question.asked':
          state(p.sessionID).asked.add(p.id)
          return publish()
        case 'question.replied':
          state(p.sessionID).asked.delete(p.requestID ?? p.id)
          return publish()
        // session.error is not a wait: an Esc or an error is followed by
        // session.idle, and a context overflow by OpenCode's own compaction.
        case 'session.idle': {
          const s = state(p.sessionID); s.running = false; s.blocked.clear(); s.asked.clear()
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
