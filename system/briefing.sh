#!/usr/bin/env bash
# ============================================================
# HQ daily briefing — runs every morning via launchd.
# A headless Claude session writes the briefing into iCloud
# (Claude/briefings/YYYY-MM-DD.md) and pings the phone.
# Permissions: read-mostly — auto-accepts file edits (to write
# the briefing) and allows git/gh status commands, nothing else.
# ============================================================
set -uo pipefail

# launchd gives a bare PATH — add the real toolchain (node, gh, homebrew)
# so the headless session and its plugin hooks work like a normal shell.
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

HQ="$HOME/hq/system"
CLAUDE_BIN="$HOME/.local/bin/claude"
LOG="$HQ/logs/briefing-$(date +%Y%m%d).log"
NTFY_TOPIC="kairo-cf-24a92880"

# Run from home so this never depends on some other session's working dir.
cd "$HOME" || exit 1

out=$("$CLAUDE_BIN" -p "$(cat "$HQ/briefing-prompt.md")" \
  --model claude-sonnet-5 \
  --permission-mode acceptEdits \
  --allowedTools 'Bash(git:*),Bash(gh:*),Bash(ls:*)' 2>&1)
printf '%s\n' "$out" > "$LOG"

summary=$(printf '%s\n' "$out" | grep '^BRIEF: ' | head -1 | sed 's/^BRIEF: //' | cut -c1-170)
curl -fsS --max-time 10 -H "Title: ☀️ Daily briefing" \
  -d "${summary:-Briefing ready: Files → iCloud → Claude → briefings}" \
  "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
