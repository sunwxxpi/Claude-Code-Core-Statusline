#!/bin/bash
input=$(cat)

VERSION=$(echo "$input" | jq -r '.version // "?"')
MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
[ -n "$EFFORT" ] && MODEL="${MODEL} ${EFFORT}"
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
MODE=$(echo "$input" | jq -r '.output_style.name // "default"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_MAX=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
CTX_INPUT=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
CTX_CACHE_CREATE=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
CTX_CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
CTX_USED=$(( CTX_INPUT + CTX_CACHE_CREATE + CTX_CACHE_READ ))
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Format token count as human-readable (e.g. 12345 -> "12k", 200000 -> "200k")
_fmt_tokens() {
    local n="$1"
    if [ "$n" -ge 1000 ]; then
        echo "$(( n / 1000 ))k"
    else
        echo "$n"
    fi
}

CYAN='\033[38;5;69m'; GREEN='\033[38;5;71m'; YELLOW='\033[38;5;179m'; RED='\033[31m'; PURPLE='\033[38;5;141m'; RESET='\033[0m'

# Fetch Anthropic OAuth usage percentage from api.anthropic.com/api/oauth/usage
_USAGE_CACHE="$HOME/.claude/usage_pct_cache.json"
_NOW=$(date +%s)

# Refresh usage data synchronously on every response
_tok=$(jq -r '.claudeAiOauth.accessToken // empty' \
    "$HOME/.claude/.credentials.json" 2>/dev/null)
if [ -n "$_tok" ]; then
    curl -sf --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $_tok" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -o "${_USAGE_CACHE}.tmp" 2>/dev/null && \
    mv "${_USAGE_CACHE}.tmp" "$_USAGE_CACHE"
fi

# Format usage string as e.g. "5h 9% [=--------] (4h22m)"
_fmt_usage() {
    local label="$1" util="$2" resets_at="$3"
    [ -z "$util" ] && return
    local pct txt reset_epoch diff h m
    pct=$(printf '%.0f' "$util" 2>/dev/null || echo "$util")
    local filled=$(( pct / 10 )) empty=$(( 10 - pct / 10 ))
    local bar="[$(printf "%${filled}s" | tr ' ' '=')$(printf "%${empty}s" | tr ' ' '-')]"
    txt="${label} ${pct}% ${bar}"
    if [ -n "$resets_at" ]; then
        reset_epoch=$(date -d "$resets_at" +%s 2>/dev/null) || { printf '%s' "$txt"; return; }
        diff=$(( reset_epoch - _NOW ))
        if [ "$diff" -gt 0 ]; then
            h=$(( diff / 3600 )); m=$(( (diff % 3600) / 60 ))
            if   [ "$h" -gt 24 ]; then txt="${txt} ($(( h/24 ))d$(( h%24 ))h)"
            elif [ "$h" -gt  0 ]; then txt="${txt} (${h}h${m}m)"
            else                       txt="${txt} (${m}m)"
            fi
        fi
    fi
    printf '%s' "$txt"
}

USAGE_STR=""
if [ -f "$_USAGE_CACHE" ]; then
    _FIVE=$(_fmt_usage "5h" \
        "$(jq -r '.five_hour.utilization // empty' "$_USAGE_CACHE" 2>/dev/null)" \
        "$(jq -r '.five_hour.resets_at   // empty' "$_USAGE_CACHE" 2>/dev/null)")
    _SEVEN=$(_fmt_usage "7d" \
        "$(jq -r '.seven_day.utilization // empty' "$_USAGE_CACHE" 2>/dev/null)" \
        "$(jq -r '.seven_day.resets_at   // empty' "$_USAGE_CACHE" 2>/dev/null)")
    [ -n "$_FIVE$_SEVEN" ] && USAGE_STR=" \033[38;5;179m| ${_FIVE} | ${_SEVEN}\033[0m"
fi

BAR_COLOR="$GREEN"

# Context window progress bar (10 segments)
FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR="[$(printf "%${FILLED}s" | tr ' ' '=')$(printf "%${EMPTY}s" | tr ' ' '-')]"

COST_FMT=$(printf '$%.2f' "$COST")

# Git branch (silently skipped if not in a git repo or detached HEAD)
BRANCH=""
_BR=$(git branch --show-current 2>/dev/null)
[ -n "$_BR" ] && BRANCH=" ($_BR)"

# Line 1: version, model, directory|branch, mode
printf '%b\n' "v${VERSION} | ${PURPLE}${MODEL}${RESET} | ${CYAN}${DIR##*/}${BRANCH}${RESET} | ${MODE}"
# Line 2: context window usage bar
CTX_USED_FMT=$(_fmt_tokens "$CTX_USED")
CTX_MAX_FMT=$(_fmt_tokens "$CTX_MAX")
printf '%b\n' "${GREEN}Context: ${PCT}% ${BAR} (${CTX_USED_FMT} / ${CTX_MAX_FMT})${RESET}"
# Line 3: session cost + plan utilization
printf '%b\n' "${YELLOW}${COST_FMT}${RESET}${USAGE_STR}"
