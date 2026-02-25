#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
info()    { printf "${CYAN}[INFO]${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; exit 1; }

# ─── Dependency check ───────────────────────────────────────────────────────
check_deps() {
    command -v jq &>/dev/null || error "Missing required dependency: jq
  Install it first:
    macOS:  brew install jq
    Ubuntu: sudo apt install jq
    Arch:   sudo pacman -S jq"

    if ! command -v curl &>/dev/null; then
        warn "curl not found — the 5h/7d usage stats will not be available."
        warn "Install curl to enable plan utilization tracking."
    fi
}

# ─── Main install ───────────────────────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/sunwxxpi/Claude-Code-Core-Statusline/main"
CLAUDE_DIR="$HOME/.claude"
SCRIPT_DST="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

info "Checking dependencies..."
check_deps
success "Dependency check passed."

info "Setting up ~/.claude directory..."
mkdir -p "$CLAUDE_DIR"

# Detect whether a local copy of statusline-command.sh exists beside this script.
# When run via `curl ... | bash`, BASH_SOURCE[0] is empty or "bash", so we download instead.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo "")"
_SCRIPT_SRC="$_SCRIPT_DIR/statusline-command.sh"

if [ -f "$_SCRIPT_SRC" ]; then
    info "Copying statusline-command.sh → $SCRIPT_DST"
    cp "$_SCRIPT_SRC" "$SCRIPT_DST"
else
    command -v curl &>/dev/null || error "curl is required to download statusline-command.sh.
  Install curl or use 'git clone' install method instead."
    info "Downloading statusline-command.sh from GitHub..."
    curl -fsSL "$REPO_RAW/statusline-command.sh" -o "$SCRIPT_DST"
fi
chmod +x "$SCRIPT_DST"
success "Script installed."

info "Updating $SETTINGS..."

# Create settings.json if missing, otherwise merge statusLine into existing file
if [ ! -f "$SETTINGS" ]; then
    cat > "$SETTINGS" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "bash $SCRIPT_DST"
  }
}
EOF
    success "Created $SETTINGS with statusLine config."
else
    # Skip if statusLine is already configured
    if jq -e '.statusLine' "$SETTINGS" &>/dev/null; then
        warn "statusLine is already configured in $SETTINGS — skipping."
        warn "To update manually, set:"
        warn "  \"statusLine\": { \"type\": \"command\", \"command\": \"bash $SCRIPT_DST\" }"
    else
        # Back up existing file and merge statusLine into it
        cp "$SETTINGS" "${SETTINGS}.bak"
        info "Backup saved: ${SETTINGS}.bak"
        tmp=$(mktemp)
        jq --arg cmd "bash $SCRIPT_DST" \
            '. + {"statusLine": {"type": "command", "command": $cmd}}' \
            "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
        success "statusLine added to $SETTINGS."
    fi
fi

echo ""
success "Installation complete!"
info "Restart Claude Code to apply the new statusline."
