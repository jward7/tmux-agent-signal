// tmux-agent-signal for OpenCode plugin API v2 (TUI plugin). Copy this
// directory to ~/.config/opencode/plugins/tmux-agent-signal/ and restart
// OpenCode. Headless `opencode run` is not tracked: only the terminal UI
// knows which pane it is in.
//
// A simplified port of workmux's OpenCode V2 plugin: the word for the window
// is derived from every session the TUI shows (root and subagents). A
// pending permission or form anywhere is blocked; otherwise a running
// session is working; otherwise done.
import { execFile } from 'node:child_process';
import { Plugin } from '@opencode/plugin/tui';

type State = { running: boolean; pending: Set<string> };

const report = (word: string) => {
  if (!process.env.TMUX || !process.env.TMUX_PANE) return;
  const args = word === 'clear' ? ['clear'] : ['set', word];
  execFile('sh', ['-c', 'AGENT_KIND=opencode exec "$(tmux show -gv @agent_signal_command)" "$@"', 'sh', ...args], () => {});
};

export default Plugin.define({
  id: 'tmux-agent-signal',
  setup(ctx) {
    if (!process.env.TMUX || !process.env.TMUX_PANE) return;
    const sessions = new Map<string, State>();
    const state = (id: string): State => {
      let s = sessions.get(id);
      if (!s) { s = { running: false, pending: new Set() }; sessions.set(id, s); }
      return s;
    };
    let reported: string | undefined;
    const publish = () => {
      let word = 'done';
      for (const s of sessions.values()) {
        if (s.pending.size) { word = 'blocked'; break; }
        if (s.running) word = 'working';
      }
      if (word === 'done' && reported === undefined) return;
      if (word === reported) return;
      reported = word;
      report(word);
    };

    report('idle');
    const stop = ctx.data.listen(({ details: event }: any) => {
      const d = event.data ?? {};
      switch (event.type) {
        case 'session.execution.started':
          state(d.sessionID).running = true; break;
        case 'session.execution.succeeded':
        case 'session.execution.failed':
        case 'session.execution.interrupted': {
          const s = state(d.sessionID); s.running = false; s.pending.clear(); break;
        }
        case 'permission.asked':
          state(d.sessionID).pending.add(`permission:${d.id}`); break;
        case 'permission.replied':
          state(d.sessionID).pending.delete(`permission:${d.requestID}`); break;
        case 'form.created':
          state(d.form.sessionID).pending.add(`form:${d.form.id}`); break;
        case 'form.replied':
        case 'form.cancelled':
          state(d.sessionID).pending.delete(`form:${d.id}`); break;
        case 'session.deleted':
          sessions.delete(d.sessionID); break;
        default:
          return;
      }
      publish();
    });
    return () => { stop(); sessions.clear(); report('clear'); };
  },
});
