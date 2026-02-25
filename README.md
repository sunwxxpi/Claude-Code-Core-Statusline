# Claude-Code-Core-Statusline

A rich, informative status line for [Claude Code](https://claude.ai/code) that shows model info, context usage, session cost, and your Anthropic plan utilization — all in 3 compact lines.

```
📋 v1.0.0  🤖 claude-sonnet-4-6  📁 my-project | main  ⚙️ default
🧠 Context Used: 34% [===-------]
💰 $0.12  | 5h 34% [===-------] (4h22m) | 7d 9% [----------] (6d12h)
```

---

## Features

| Field | Description |
|-------|-------------|
| `📋 v...` | Claude Code version |
| `🤖 model` | Active model name |
| `📁 dir \| branch` | Current directory and git branch (if in a repo) |
| `⚙️ mode` | Output style (default / auto, etc.) |
| `🧠 Context Used` | Context window usage % with progress bar |
| `💰 $x.xx` | Cumulative session cost |
| `5h xx%` | 5-hour rolling usage against your Anthropic plan limit |
| `7d xx%` | 7-day rolling usage against your Anthropic plan limit |

> **Note:** The `5h` / `7d` usage fields require a Claude.ai OAuth login (Claude Code's built-in login). They will be silently skipped if you use an API key instead.

---

## Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| `bash` | Yes | Pre-installed on Linux and macOS |
| `jq` | Yes | Usually needs manual install — may already be present (e.g. bundled with Anaconda) |
| `curl` | For usage stats only | Pre-installed on most systems; only needed for `5h`/`7d` fields |
| `git` | No | Pre-installed on most dev environments; only needed for branch display |

Check if `jq` is already available first:

```bash
jq --version
```

If not found, install it:

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt install jq

# Arch Linux
sudo pacman -S jq
```

---

## Quick Install

### Option 1: curl (no git required)

Downloads only the script file — simplest option.

```bash
curl -fsSL https://raw.githubusercontent.com/sunwxxpi/Claude-Code-Core-Statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh && chmod +x ~/.claude/statusline-command.sh
```

Then add the `statusLine` block to `~/.claude/settings.json` manually (see [Manual Install](#manual-install) step 2).

### Option 2: git clone (includes install.sh)

Clones the full repo and runs the automated installer, which also updates `settings.json`.

```bash
git clone https://github.com/sunwxxpi/Claude-Code-Core-Statusline.git
cd Claude-Code-Core-Statusline
bash install.sh
```

Then **restart Claude Code**.

---

## Manual Install

### 1. Copy the script

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

### 2. Edit `~/.claude/settings.json`

Add the `statusLine` block. If the file doesn't exist yet, create it:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /home/YOUR_USERNAME/.claude/statusline-command.sh"
  }
}
```

> Replace `/home/YOUR_USERNAME` with your actual home directory path (`echo $HOME`).
> On macOS, this is typically `/Users/YOUR_USERNAME`.

If you already have a `settings.json`, add only the `statusLine` key:

```json
{
  "permissions": { "defaultMode": "default" },
  "statusLine": {
    "type": "command",
    "command": "bash /home/YOUR_USERNAME/.claude/statusline-command.sh"
  }
}
```

### 3. Restart Claude Code

The statusline stays visible throughout your session and refreshes after each response.

---

## How It Works

After each response, Claude Code pipes a JSON payload to the command defined in `statusLine.command` and refreshes the statusline with the output. The script:

1. Parses model, version, directory, cost, and context usage from the payload.
2. Reads your OAuth access token from `~/.claude/.credentials.json` and calls `https://api.anthropic.com/api/oauth/usage` to fetch plan utilization.
3. Caches the usage response to `~/.claude/usage_pct_cache.json`.
4. Prints 3 formatted lines to stdout, which Claude Code uses to refresh the persistent statusline display.

---

## Troubleshooting

**Statusline not showing**
- Make sure the `command` path in `settings.json` uses your actual home directory.
- Check that `statusline-command.sh` is executable: `ls -l ~/.claude/statusline-command.sh`
- Run the script manually to test: `echo '{}' | bash ~/.claude/statusline-command.sh`

**`5h` / `7d` usage not showing**
- This requires logging in via `claude login` (OAuth flow), not an API key.
- Check that `~/.claude/.credentials.json` contains a `claudeAiOauth.accessToken` field.

**`jq: command not found`**
- Install `jq` (see Prerequisites above).

**Usage API returns errors**
- The `anthropic-beta: oauth-2025-04-20` header is a beta API and may change. Check this repository for updates.

---

## License

MIT
