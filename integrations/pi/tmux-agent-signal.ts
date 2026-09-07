// tmux-agent-signal for Pi. Copy into your Pi extensions directory.
// Typed loosely on purpose so it needs nothing installed.
import { execFile } from "node:child_process";

const report = (args: string[]) => {
  if (!process.env.TMUX) return;
  execFile("sh", ["-c", 'AGENT_KIND=pi exec "$(tmux show -gv @agent_signal_command)" "$@"', "sh", ...args], () => {});
};

export default function (pi: any) {
  pi.on("session_start",    () => report(["set", "idle"]));
  pi.on("agent_start",      () => report(["set", "working"]));
  pi.on("ui_prompt_start",  () => report(["set", "ask"]));
  pi.on("agent_settled",    () => report(["set", "done"]));
  pi.on("session_shutdown", () => report(["clear"]));
}
