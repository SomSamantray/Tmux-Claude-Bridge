# Tmux-Claude-Bridge

**Route tasks between Claude Code, Gemini CLI, and Codex CLI — all from inside your Claude window.**

No copy-paste. No window switching. Type `/send gemini "design this"` and the response
appears right back in your Claude session, automatically.

---

## What is this?

Tmux-Claude-Bridge (AICOMM) is a Claude Code plugin that lets multiple AI sessions on the same
machine talk to each other through tmux. You stay in Claude Code. Claude Code sends your message
to Gemini or Codex, waits for the answer, and prints it back inline.

Think of it as a **walkie-talkie for AI terminals**.

```
You (in Claude Code)
      │
      │  /send gemini-ui "design the login form"
      ▼
 aicomm CLI  ──► queue file  ──► background daemon
                                        │
                                  tmux send-keys
                                        │
                                        ▼
                                  Gemini window
                                  (processes task)
                                        │
                                  ###AICOMM_END###
                                        │
                                        ▼
                              daemon extracts response
                                        │
                                 cat response file
                                        │
                                        ▼
                              Response appears in your
                              Claude window  ✔
```

Every exchange is also logged to `CONTEXT.md` in your project — so all AI sessions share a
running history of what each has done.

---

## Prerequisites

You need four things installed before AICOMM works:

| Dependency | Why | Install |
|-----------|-----|---------|
| **tmux** | The IPC backbone — AI sessions run as tmux windows | `brew install tmux` |
| **python3** | Runs the background daemon | Comes with macOS, or `brew install python3` |
| **Gemini CLI** | To send tasks to Google's Gemini | `npm install -g @google/gemini-cli` |
| **Codex CLI** | To send tasks to OpenAI's Codex | `npm install -g @openai/codex` |

The installer checks all of these and tells you exactly what to install if anything is missing.

> **Note:** You do not need Gemini or Codex if you only want to route between Claude sessions.
> Only install what you plan to use.

---

## Install

### Option A — Direct install (recommended)

```bash
git clone https://github.com/SomSamantray/Tmux-Claude-Bridge.git
cd Tmux-Claude-Bridge
bash install.sh
```

### Option B — One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/SomSamantray/Tmux-Claude-Bridge/main/install.sh | bash
```

Then **restart Claude Code**.

### What the installer does

1. Copies `aicomm`, `aicomm-daemon`, `mygemini`, `mycodex` → `~/bin/`
2. Adds `~/bin` to your PATH (in `~/.zshrc` and/or `~/.bashrc`)
3. Installs the `/send` slash command → `~/.claude/commands/send.md`
4. Enables the plugin in `~/.claude/settings.json`
5. Checks all dependencies and prints install commands for anything missing

---

## Quick Start

Open Claude Code, navigate to your project folder, and type:

```
/send gemini-ui design a responsive navbar with dark mode support
```

**First time:** AICOMM will ask if you want to start the `gemini-ui` session.
Confirm and it creates a tmux window, launches Gemini, and routes your message.

**After that:** messages route silently. The response appears inline.

---

## Usage

### Send to one session

```
/send <alias> <your message>
```

```
/send gemini-ui design the login page with a clean modern layout
/send codex-backend implement a REST API for user authentication
/send claude-review review the PR diff and flag any security issues
```

### Broadcast to all sessions at once

```
/send all summarise what you have each built so far
```

### From the terminal (same as /send)

```bash
aicomm send gemini-ui "design the settings page"
aicomm send all "what is everyone working on?"
```

---

## Session Aliases

Aliases are short names you give to each AI session. AICOMM infers which tool to use from the prefix:

| Prefix | Tool used |
|--------|-----------|
| `gemini-*` | Gemini CLI |
| `codex-*` | Codex CLI |
| `claude-*` | Claude Code |

**Examples:**

| Alias | What it's for |
|-------|--------------|
| `gemini-ui` | Gemini handling frontend / design |
| `gemini-research` | Gemini for research tasks |
| `codex-backend` | Codex handling backend code |
| `codex-tests` | Codex writing tests |
| `claude-review` | Another Claude session for code review |

You can name them anything — the prefix just tells AICOMM which tool to launch.

---

## How It Works (Under the Hood)

```
Step 1 — You type:
  /send gemini-ui "design a navbar"

Step 2 — aicomm CLI:
  • Checks registry for 'gemini-ui'
  • If not found: asks y/n, creates a tmux window, launches gemini
  • Writes a JSON message to .aicomm/queue/<uuid>.json
  • Starts background Python daemon (if not already running)

Step 3 — Daemon (aicomm-daemon):
  • Scans queue every 0.3 seconds
  • Picks up the message
  • Runs: tmux send-keys -t <pane> 'mygemini "design a navbar"' Enter

Step 4 — Gemini window:
  • mygemini wrapper calls: gemini "design a navbar"
  • When done, wrapper prints: ###AICOMM_END###

Step 5 — Daemon detects the marker:
  • Polls tmux capture-pane every 0.5 seconds
  • Counts occurrences of ###AICOMM_END### (ignores stale ones from before)
  • When a new one appears: extracts the response text

Step 6 — Response delivery:
  • Writes response to .aicomm/responses/<uuid>.txt
  • Appends the exchange to CONTEXT.md with timestamp
  • Runs: tmux send-keys -t <your-pane> 'cat .aicomm/responses/<uuid>.txt' Enter

Step 7 — You see:
  --- RESPONSE FROM GEMINI-UI [14:23:05] ---
  Here's a responsive navbar with dark mode...
  --- END GEMINI-UI RESPONSE ---
```

**Why write to a file and `cat` it?**
AI responses contain special characters (backticks, brackets, quotes, ANSI codes) that would
break if injected directly via `tmux send-keys`. Writing to a file and running `cat` avoids
all shell-escaping issues.

**Why tmux?**
Gemini and Codex are interactive terminal programs — they need a real terminal (a tty) to run.
Tmux provides that. It also lets the daemon read output without interfering with the sessions.

---

## Shared Context (CONTEXT.md)

Every exchange between sessions is automatically appended to `CONTEXT.md` in your project:

```markdown
## [2026-03-28 14:23:05] shell → gemini-ui

**Task:** design a responsive navbar with dark mode support

**Response:**
Here's a responsive navbar component...

---
```

This means every AI session can read `CONTEXT.md` to see what the others have done — great for
keeping a multi-agent team in sync on the same codebase.

---

## Session Management

```bash
# See all registered sessions
aicomm list

# Check daemon status + queue
aicomm status

# Manually register an existing tmux pane
aicomm register gemini-ui --tmux aicomm:1.0 --tool gemini

# Start a new session (creates tmux window + launches tool)
aicomm start gemini-ui --tool gemini

# Stop a session (kills window + removes from registry)
aicomm stop gemini-ui
```

---

## File Structure

```
Tmux-Claude-Bridge/
├── bin/
│   ├── aicomm           Main Bash CLI — all commands
│   ├── aicomm-daemon    Python3 background daemon
│   ├── mygemini         Gemini CLI wrapper (adds end marker)
│   └── mycodex          Codex CLI wrapper (adds end marker)
├── commands/
│   └── send.md          Claude Code /send slash command
├── hooks/
│   ├── hooks.json       Claude Code SessionStart hook registration
│   └── startup.mjs      Dep check + daemon watchdog on session start
├── .claude-plugin/
│   └── plugin.json      Claude Code plugin manifest
├── install.sh           One-time installer
└── README.md            This file
```

**Per-project runtime files** (created in your project directory on first use):

```
your-project/
└── .aicomm/
    ├── registry.json       alias → tmux pane mapping
    ├── daemon.pid          background daemon process ID
    ├── daemon.log          daemon output log
    ├── queue/              pending messages (JSON files)
    └── responses/          response files (one per exchange)
```

---

## Troubleshooting

### "Session not found" even after auto-starting

The daemon may not have started. Check:
```bash
cat .aicomm/daemon.log
aicomm status
```

### Response never appears (timeout after 120s)

- Check that the target session is actually running: `tmux list-windows -a`
- Check the wrapper script manually: `mygemini "hello"`
- Look at daemon log: `cat .aicomm/daemon.log`

### Wrong session gets the response

Make sure you are running `aicomm send` from inside a tmux session.
The daemon detects your current pane via `tmux display-message`.

### Gemini / Codex output has extra noise

Stderr is redirected to `/tmp/aicomm-gemini-stderr.log` and `/tmp/aicomm-codex-stderr.log`.
Check those files if you suspect an error in the tool itself.

### PATH not updated after install

Run:
```bash
source ~/.zshrc   # or ~/.bashrc
which aicomm      # should print ~/bin/aicomm
```

---

## License

MIT

---

## Credits

Built as a Claude Code community plugin. Uses tmux as a zero-dependency IPC backbone.
Works with any combination of Claude Code, Gemini CLI, and Codex CLI.
