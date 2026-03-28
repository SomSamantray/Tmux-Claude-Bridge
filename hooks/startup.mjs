#!/usr/bin/env node
/**
 * startup.mjs — AICOMM SessionStart hook
 *
 * Runs on every Claude Code session start (startup + resume).
 * Does two things:
 *   1. Dep check — warns once if tmux, gemini, or codex are missing
 *   2. Daemon watchdog — if .aicomm/ exists in CWD and daemon is stale, restarts it
 */

import { execSync, spawnSync } from "child_process";
import { existsSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function which(cmd) {
  const r = spawnSync("which", [cmd], { encoding: "utf8" });
  return r.status === 0 && r.stdout.trim().length > 0;
}

function pidAlive(pid) {
  try {
    process.kill(Number(pid), 0);
    return true;
  } catch {
    return false;
  }
}

// ─── 1. Dep check ─────────────────────────────────────────────────────────────

const missing = [];
if (!which("tmux"))   missing.push({ name: "tmux",   fix: "brew install tmux" });
if (!which("python3")) missing.push({ name: "python3", fix: "brew install python3" });
if (!which("gemini")) missing.push({ name: "gemini",  fix: "npm install -g @google/gemini-cli" });
if (!which("codex"))  missing.push({ name: "codex",   fix: "npm install -g @openai/codex" });

// Only warn once per day (suppress repeat nagging)
const warnFile = join(homedir(), ".aicomm-dep-warned");
let alreadyWarned = false;
if (existsSync(warnFile)) {
  const ts = Number(readFileSync(warnFile, "utf8").trim());
  if (Date.now() - ts < 86_400_000) alreadyWarned = true;
}

if (missing.length > 0 && !alreadyWarned) {
  const lines = missing.map(d => `  • ${d.name} missing — install with: ${d.fix}`).join("\n");
  console.log(`\n⚠️  AICOMM: some dependencies are missing:\n${lines}\n  AICOMM messaging will not work until these are installed.\n`);
  writeFileSync(warnFile, String(Date.now()));
}

// ─── 2. Daemon watchdog ───────────────────────────────────────────────────────

const cwd = process.cwd();
const pidFile = join(cwd, ".aicomm", "daemon.pid");
const logFile = join(cwd, ".aicomm", "daemon.log");

if (existsSync(pidFile)) {
  const pid = readFileSync(pidFile, "utf8").trim();
  if (pid && !pidAlive(pid)) {
    // Stale pidfile — restart daemon silently
    const daemonBin =
      process.env.AICOMM_DAEMON_BIN ||
      join(homedir(), "bin", "aicomm-daemon");

    if (existsSync(daemonBin)) {
      const child = spawnSync("nohup", ["python3", daemonBin, cwd], {
        detached: true,
        stdio: ["ignore", "ignore", "ignore"],
        env: { ...process.env },
      });
      // Best-effort restart — errors are silent so they don't interrupt the session
    }
  }
}
