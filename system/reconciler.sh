#!/usr/bin/env bash
# ============================================================
# HQ reconciler — runs weekly via launchd.
# Checks claims in control/*.md and the memory fact files against
# actual PR/branch state on GitHub, fixes what's gone stale, and
# mines the week's finished work into MemPalace for long-term recall.
# ============================================================
set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

HQ="$HOME/hq/system"
CLAUDE_BIN="$HOME/.local/bin/claude"
LOG="$HQ/logs/reconciler-$(date +%Y%m%d).log"
RUNS="$HQ/runs.jsonl"
NTFY_TOPIC="kairo-cf-24a92880"

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'; }
log_event() {
  printf '{"ts":"%s","event":"%s","item":"%s","model":"%s","status":"%s","secs":%s,"pr":"%s"}\n' \
    "$(now_iso)" "$(json_escape "$1")" "$(json_escape "$2")" "$(json_escape "$3")" \
    "$(json_escape "$4")" "${5:-0}" "$(json_escape "${6:-}")" >> "$RUNS"
}

cd "$HOME" || exit 1
t0=$(date +%s)

out=$("$CLAUDE_BIN" -p "$(cat "$HQ/reconciler-prompt.md")" \
  --model claude-sonnet-5 \
  --permission-mode acceptEdits \
  --allowedTools 'Bash(gh:*),Bash(git:*),Bash(mempalace:*),Bash(ls:*),mcp__mempalace__mempalace_mine,mcp__mempalace__mempalace_search' 2>&1)
printf '%s\n' "$out" > "$LOG"

summary=$(printf '%s\n' "$out" | grep '^RECONCILED: ' | tail -1 | sed 's/^RECONCILED: //')
log_event reconcile "" claude-sonnet-5 "${summary:-UNCLEAR}" "$(( $(date +%s) - t0 ))" ""

if [ -n "$summary" ]; then
  ping() { curl -fsS --max-time 10 -H "Title: $1" -d "$2" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true; }
  ping "🧹 HQ — weekly memory check" "$summary"
fi

# Commit any edits it made to control/ or memory files.
if [ -d "$HOME/hq/.git" ] && [ -n "$(git -C "$HOME/hq" status --porcelain)" ]; then
  git -C "$HOME/hq" add -A
  git -C "$HOME/hq" -c user.name="HQ reconciler" -c user.email="hq@localhost" \
    commit -q -m "hq: reconciler run $(date +%Y-%m-%d) — ${summary:-no summary}" || true
  git -C "$HOME/hq" push -q origin HEAD 2>/dev/null || true
fi
