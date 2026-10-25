// tmux-agent-signal for Pi. Copy into your Pi extensions directory.
// Typed loosely on purpose so it needs nothing installed.
import { execFile } from "node:child_process";

// Reports are serialised so an older one can never land after a newer one.
let queue: Promise<void> = Promise.resolve();
const report = (args: string[]) => {
  if (!process.env.TMUX || !process.env.TMUX_PANE) return queue;
  queue = queue.then(() => new Promise<void>((done) => {
    execFile("sh", ["-c", 'AGENT_KIND=pi exec "$(tmux show -gv @agent_signal_command)" "$@"', "sh", ...args], () => done());
  }));
  return queue;
};

export default function (pi: any) {
  pi.on("session_start",    () => report(["set", "idle"]));
  pi.on("agent_start",      () => report(["set", "working"]));
  pi.on("ui_prompt_start",  () => report(["set", "ask"]));
  // An aborted turn (Esc, or an interrupted compaction Pi retries by itself)
  // settles too. workmux keeps those "working" and relies on a pane-inactivity
  // detector to recover; this plugin has no detector, so done it is: a stale
  // done after a retry is a small cost, a stuck working after Esc is not.
  pi.on("agent_settled",    () => report(["set", "done"]));
  pi.on("session_shutdown", () => report(["clear"]));
}
