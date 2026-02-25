#!/usr/bin/env bash
set -euo pipefail

# ─── 색상 ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
info()    { printf "${CYAN}[INFO]${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; exit 1; }

# ─── 의존성 확인 ────────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    command -v jq   &>/dev/null || missing+=("jq")
    command -v curl &>/dev/null || missing+=("curl")
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing[*]}
  Install them first:
    macOS:  brew install ${missing[*]}
    Ubuntu: sudo apt install ${missing[*]}
    Arch:   sudo pacman -S ${missing[*]}"
    fi
}

# ─── 메인 설치 ──────────────────────────────────────────────────────────────
CLAUDE_DIR="$HOME/.claude"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline-command.sh"
SCRIPT_DST="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

info "Checking dependencies..."
check_deps
success "jq and curl found."

info "Setting up ~/.claude directory..."
mkdir -p "$CLAUDE_DIR"

info "Copying statusline-command.sh → $SCRIPT_DST"
cp "$SCRIPT_SRC" "$SCRIPT_DST"
chmod +x "$SCRIPT_DST"
success "Script installed."

info "Updating $SETTINGS..."

# settings.json 처리: 없으면 생성, 있으면 merge
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
    # 이미 statusLine이 설정돼 있으면 스킵
    if jq -e '.statusLine' "$SETTINGS" &>/dev/null; then
        warn "statusLine is already configured in $SETTINGS — skipping."
        warn "To update manually, set:"
        warn "  \"statusLine\": { \"type\": \"command\", \"command\": \"bash $SCRIPT_DST\" }"
    else
        # 백업 후 merge
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
