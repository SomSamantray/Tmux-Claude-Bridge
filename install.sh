#!/usr/bin/env bash
# AICOMM Plugin Installer
# curl -fsSL https://raw.githubusercontent.com/SomSamantray/Tmux-Claude-Bridge/main/install.sh | bash
set -euo pipefail

# ─── Setup ────────────────────────────────────────────────────────────────────

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/bin"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

ok()   { printf '\033[32m  ✔\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m  ⚠\033[0m  %s\n' "$*"; }
info() { printf '\033[36m  ➜\033[0m  %s\n' "$*"; }

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║   AICOMM Plugin Installer            ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# ─── 1. Create ~/bin/ ─────────────────────────────────────────────────────────

mkdir -p "$BIN_DIR"

# ─── 2. Copy scripts ──────────────────────────────────────────────────────────

for script in aicomm aicomm-daemon mygemini mycodex; do
  cp "$PLUGIN_DIR/bin/$script" "$BIN_DIR/$script"
  chmod +x "$BIN_DIR/$script"
done
ok "Scripts installed to $BIN_DIR/"

# ─── 3. Add ~/bin to PATH ─────────────────────────────────────────────────────

PATH_LINE='export PATH="$HOME/bin:$PATH"'
added_path=false

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]] && ! grep -qF 'HOME/bin' "$rc"; then
    printf '\n# Added by AICOMM installer\n%s\n' "$PATH_LINE" >> "$rc"
    added_path=true
  fi
done

if $added_path; then
  ok "Added ~/bin to PATH in shell config"
else
  ok "~/bin already in PATH config"
fi

# Also export for this process so subsequent steps can find the bins
export PATH="$BIN_DIR:$PATH"

# ─── 4. Auto-tmux wrapper for claude ─────────────────────────────────────────

CLAUDE_WRAPPER='
# AICOMM: auto-wrap claude in tmux so /send always works
claude() {
  if [ -z "$TMUX" ]; then
    local _session="claude-$(basename "$(pwd)")"
    exec tmux new-session -A -s "$_session" "command claude $*"
  else
    command claude "$@"
  fi
}'

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]] && ! grep -q 'AICOMM: auto-wrap claude' "$rc"; then
    printf '\n%s\n' "$CLAUDE_WRAPPER" >> "$rc"
    ok "Added auto-tmux claude wrapper to $rc"
  fi
done

# ─── 5. Install /send slash command ──────────────────────────────────────────

mkdir -p "$CLAUDE_COMMANDS_DIR"
cp "$PLUGIN_DIR/commands/send.md" "$CLAUDE_COMMANDS_DIR/send.md"
ok "/send command installed to $CLAUDE_COMMANDS_DIR/"

# ─── 6. Register plugin in Claude Code settings ──────────────────────────────

mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

python3 - <<'PYEOF'
import json, os, sys

settings_path = os.path.expanduser("~/.claude/settings.json")

if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except Exception:
        settings = {}
else:
    settings = {}

# Enable plugin
plugins = settings.setdefault("plugins", {})
plugins["aicomm@community"] = True

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("  \033[32m  ✔\033[0m  Plugin enabled in Claude Code settings")
PYEOF

# ─── 7. Dep checks ────────────────────────────────────────────────────────────

echo ""
info "Checking dependencies..."
echo ""

check_dep() {
  local cmd="$1" fix="$2"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver=$("$cmd" --version 2>/dev/null | head -1 || echo "found")
    ok "$cmd found ($ver)"
  else
    warn "$cmd NOT found — install with: $fix"
  fi
}

check_dep tmux   "brew install tmux"
check_dep python3 "brew install python3"
check_dep gemini "npm install -g @google/gemini-cli"
check_dep codex  "npm install -g @openai/codex"

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "  ─────────────────────────────────────────"
ok  "AICOMM installed!"
echo ""
info "Restart Claude Code, then navigate to your project and type:"
echo ""
echo '    /send gemini-ui "design the login form"'
echo '    /send codex-backend "implement the API"'
echo '    /send all "summarise what you have done"'
echo ""
info "If a session is not running yet, AICOMM will ask you to start it."
echo ""
