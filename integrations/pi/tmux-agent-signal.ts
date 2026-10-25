// tmux-agent-signal for Pi. Copy into your Pi extensions directory.
// Typed loosely on purpose so it needs nothing installed.
import { execFile } from "node:child_process";

const report = (args: string[]) => {
  if (!process.env.TMUX || !process.env.TMUX_PANE) return;
  execFile("sh", ["-c", 'AGENT_KIND=pi exec "$(tmux show -gv @agent_signal_command)" "$@"', "sh", ...args], () => {});
};

// Pi settles after an aborted turn too (a compaction or retry it will carry
// on from by itself). Reporting done there flashes a finish that is not one.
const latestAssistantWasAborted = (ctx: any): boolean => {
  const branch: any[] = ctx?.sessionManager?.getBranch?.() ?? [];
  for (let i = branch.length - 1; i >= 0; i--) {
    const e = branch[i];
    if (e?.type !== "message" || e.message?.role !== "assistant") continue;
    return e.message.stopReason === "aborted" ||
      (e.message.stopReason === "error" && /\boperation was aborted\b/i.test(e.message.errorMessage ?? ""));
  }
  return false;
};

export default function (pi: any) {
  pi.on("session_start",    () => report(["set", "idle"]));
  pi.on("agent_start",      () => report(["set", "working"]));
  pi.on("ui_prompt_start",  () => report(["set", "ask"]));
  pi.on("agent_settled",    (_e: any, ctx: any) => { if (!latestAssistantWasAborted(ctx)) report(["set", "done"]); });
  pi.on("session_shutdown", () => report(["clear"]));
}
