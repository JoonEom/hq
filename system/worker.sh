#!/usr/bin/env bash
# ============================================================
# HQ worker — the unattended agent. Runs hourly via launchd.
#
# Each run:
#   1. If inbox.md has notes, file them into queue.md.
#   2. Work the top READY task, up to MAX_ITEMS. Ping the phone.
#   3. Review each PR it opened, record what happened, commit.
#
# A task is READY when it's an open `- [ ]` line that is NOT tagged
# [YOU], NOT an (idea), NOT marked ⚠️ (blocked), and NOT under a
# "## Parked" or "## Done" heading. Nothing ready = nothing runs,
# no ping, no cost.
#
# A run that ends BLOCKED marks the item ⚠️ and moves on, so you get
# one ping instead of one per hour. Delete the ⚠️ note to retry.
#
# Model comes from the item's [model:...] tag; untagged = Opus 4.8.
#
# Files live in ~/hq/control (plain local files, tracked in git).
# There is no iCloud involvement — it caused read deadlocks and the
# symlinks it required didn't work in Orca.
# ============================================================
set -uo pipefail

# launchd starts us with a bare PATH — node/npm are in /usr/local/bin and gh in
# /opt/homebrew/bin, so give the whole run a real toolchain.
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

HQ="$HOME/hq/system"
CONTROL="$HOME/hq/control"
QUEUE="$CONTROL/queue.md"
INBOX="$CONTROL/inbox.md"
HISTORY="$CONTROL/history.md"
PROPOSED="$CONTROL/proposed.md"
SENSES_STAMP="$HQ/.last-senses"
CLAUDE_BIN="$HOME/.local/bin/claude"
LOCK="$HQ/worker.lock"
LOG="$HQ/logs/worker-$(date +%Y%m%d-%H%M).log"
RUNS="$HQ/runs.jsonl"      # append-only history: what actually happened
STATUS="$HQ/status.json"   # current state, regenerated every run
NTFY_TOPIC="kairo-cf-24a92880"
MAX_ITEMS=3
AUTOCOMMIT=1               # commit ~/hq after each run so changes have history

# Scoped, not disarmed: file edits plus common build commands are pre-approved;
# anything else is denied and the task is marked blocked rather than improvised.
ALLOWED_TOOLS='Bash(git:*),Bash(gh:*),Bash(npm:*),Bash(npx:*),Bash(node:*),Bash(bash scripts/verify.sh:*),Bash(mkdir:*),Bash(ls:*),Bash(mv:*),Bash(cp:*)'

# ---------- small helpers ----------

ping() { curl -fsS --max-time 10 -H "Title: $1" -d "$2" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true; }

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# `grep -c` prints "0" AND exits 1 on no match, so `$(grep -c … || echo 0)`
# emits two zeros and produces invalid JSON. Take grep's number; default only
# when it printed nothing at all (missing file).
count() {
  n=$(grep -cE "$1" "$2" 2>/dev/null | head -1)
  printf '%s' "${n:-0}"
}

# Queue items carry emoji, quotes and backslashes — escaping is not optional.
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'
}

log_event() {
  printf '{"ts":"%s","event":"%s","item":"%s","model":"%s","status":"%s","secs":%s,"pr":"%s"}\n' \
    "$(now_iso)" "$(json_escape "$1")" "$(json_escape "$2")" "$(json_escape "$3")" \
    "$(json_escape "$4")" "${5:-0}" "$(json_escape "${6:-}")" >> "$RUNS"
}

inbox_has_content() {
  [ -f "$INBOX" ] && awk '/WRITE BELOW THIS LINE/{f=1; next} f && NF && $0 !~ /^[[:space:]]*#/{print}' "$INBOX" | grep -q .
}

ready_items() {
  awk '
    /^##[[:space:]]/ { h=$0; next }
    h ~ /[Pp]arked/ || h ~ /[Dd]one/ { next }
    /^-[[:space:]]\[[[:space:]]?\][[:space:]]/ {
      if ($0 ~ /\[YOU\]/ || $0 ~ /\(idea\)/ || index($0, "⚠️")) next
      print
    }
  ' "$QUEUE"
}

# Mark a blocked task so it stops being re-picked (and re-pinged) hourly.
park_blocked() {
  q_line="$1" /usr/bin/awk '
    BEGIN { line = ENVIRON["q_line"]; done = 0 }
    !done && $0 == line && !index($0, "⚠️") {
      print $0 " — ⚠️ blocked (details: ~/hq/system/logs) — delete this note to retry"
      done = 1; next
    }
    { print }
  ' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
}

strip_box() { sed -E 's/^-[[:space:]]\[[[:space:]]?\][[:space:]]//'; }

# Does this item explicitly authorize merging straight to main? Joon opts in
# per-task by writing it in the note; silence always means draft PR.
wants_main_merge() {
  printf '%s' "$1" | grep -qiE 'push (to |straight to )?main|merge (to |into )?main|no pr|skip (the )?pr'
}

# Append to the permanent history. Newest first, directly under the `---` marker.
# Nothing expires here — the inbox stays clean and this becomes the long record of
# what the system actually did.
log_finished() {
  [ -f "$HISTORY" ] || printf '# History — what the agent has done\n\n---\n' > "$HISTORY"
  entry="- $(date +%Y-%m-%d\ %H:%M) — $1" /usr/bin/awk '
    BEGIN { e = ENVIRON["entry"]; done = 0 }
    !done && /^---[[:space:]]*$/ { print; print ""; print e; done = 1; next }
    { print }
    END { if (!done) { print ""; print e } }
  ' "$HISTORY" > "$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"
}

# ---------- one run ----------

if [ -e "$LOCK" ]; then
  if [ -n "$(find "$LOCK" -mmin +180 2>/dev/null)" ]; then rm -f "$LOCK"; else exit 0; fi
fi
touch "$LOCK"; trap 'rm -f "$LOCK"' EXIT

cd "$HOME" || exit 1
[ -f "$QUEUE" ] || { ping "⚠️ HQ — no queue file" "Expected $QUEUE and it isn't there."; exit 0; }

# Heartbeat: this Mac never sleeps, so a gap means a real failure, not a nap.
if [ -s "$RUNS" ]; then
  last_ts=$(tail -1 "$RUNS" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')
  if [ -n "$last_ts" ]; then
    last_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_ts" +%s 2>/dev/null || echo 0)
    gap=$(( $(date +%s) - last_epoch ))
    if [ "$last_epoch" -gt 0 ] && [ "$gap" -gt 7500 ]; then
      ping "💓 HQ — missed a cycle" "No activity for $(( gap / 3600 ))h. The hourly job may have failed. Logs: ~/hq/system/logs"
      log_event heartbeat "" "" MISSED_CYCLE "$gap" ""
    fi
  fi
fi

log_event run_start "" "" OK 0 ""

# --- senses: once a day, read Gmail + Calendar and SUGGEST work ---
# Suggestions land in proposed.md and do nothing until Joon ticks them. Email is
# written by other people, so it can never reach the queue without him in between.
# Read-only Gmail/Calendar tools only — no send, no reply, no delete.
if [ ! -f "$SENSES_STAMP" ] || [ -n "$(find "$SENSES_STAMP" -mmin +1200 2>/dev/null)" ]; then
  t0=$(date +%s)
  before_p=$(count '^-[[:space:]]\[' "$PROPOSED")
  "$CLAUDE_BIN" -p "$(cat "$HQ/senses-prompt.md")" \
    --model claude-sonnet-5 \
    --permission-mode acceptEdits \
    --allowedTools 'mcp__claude_ai_Gmail__search_threads,mcp__claude_ai_Gmail__get_thread,mcp__claude_ai_Google_Calendar__list_events,mcp__claude_ai_Google_Calendar__list_calendars' \
    >> "$LOG" 2>&1
  after_p=$(count '^-[[:space:]]\[' "$PROPOSED")
  newp=$((after_p - before_p)); [ "$newp" -lt 0 ] && newp=0
  touch "$SENSES_STAMP"
  log_event senses "" claude-sonnet-5 "PROPOSED_${newp}" "$(( $(date +%s) - t0 ))" ""
  [ "$newp" -gt 0 ] && ping "👀 HQ — noticed ${newp} thing(s)" "From your email and calendar. Tick the ones you want in ~/hq/control/proposed.md; ignore the rest."
fi

# --- approved proposals become inbox notes ---
# Joon ticks `- [x]` in proposed.md; those lines move into the inbox so normal
# intake files them like anything he wrote himself. Unticked lines stay put.
if [ -f "$PROPOSED" ] && grep -q '^-[[:space:]]\[x\]' "$PROPOSED"; then
  approved=$(grep '^-[[:space:]]\[x\]' "$PROPOSED" | sed -E 's/^-[[:space:]]\[x\][[:space:]]*//')
  printf '%s\n' "$approved" | while IFS= read -r line; do
    [ -n "$line" ] && printf '%s\n' "$line" >> "$INBOX"
  done
  grep -v '^-[[:space:]]\[x\]' "$PROPOSED" > "$PROPOSED.tmp" && mv "$PROPOSED.tmp" "$PROPOSED"
  n_appr=$(printf '%s\n' "$approved" | grep -c . || true)
  log_event approved "" "" "MOVED_${n_appr}" 0 ""
fi

# --- intake: turn free-written notes into queue items ---
if inbox_has_content; then
  before=$(count '^-[[:space:]]\[' "$QUEUE")
  "$CLAUDE_BIN" -p "$(cat "$HQ/intake-prompt.md")" \
    --model claude-haiku-4-5-20251001 \
    --permission-mode acceptEdits \
    --allowedTools 'Bash(ls:*)' >> "$LOG" 2>&1
  after=$(count '^-[[:space:]]\[' "$QUEUE")
  filed=$((after - before)); [ "$filed" -lt 0 ] && filed=0
  log_event intake "" claude-haiku-4-5-20251001 "FILED_${filed}" 0 ""
  ping "📥 HQ — got your notes" "Filed ${filed} item(s) from your inbox into the queue."
fi

# --- reviewer: a fresh session reads the diff the worker just produced ---
# Read-only. It cannot merge or edit. For draft PRs it comments; for a
# merge-to-main item it runs BEFORE the merge and can veto it.
review() {
  target="$1"; item="$2"; mode="$3"   # mode: pr | premerge
  [ -z "$target" ] && return 0
  t0=$(date +%s)
  out=$("$CLAUDE_BIN" -p "$(cat "$HQ/review-prompt.md")

MODE: $mode
TARGET: $target
TASK: $item" --model claude-haiku-4-5-20251001 \
    --permission-mode acceptEdits \
    --allowedTools 'Bash(gh pr diff:*),Bash(gh pr view:*),Bash(gh pr comment:*),Bash(git diff:*),Bash(git log:*)' 2>&1)
  printf '\n=== REVIEW (%s): %s ===\n%s\n' "$mode" "$item" "$out" >> "$LOG"
  if printf '%s' "$out" | grep -q "REVIEW: BLOCKER"; then
    log_event review "$item" claude-haiku-4-5-20251001 BLOCKER "$(( $(date +%s) - t0 ))" "$target"
    return 1
  fi
  log_event review "$item" claude-haiku-4-5-20251001 CLEAN "$(( $(date +%s) - t0 ))" "$target"
  return 0
}

work_item() {
  item="$1"
  started=$(date +%s)
  model="claude-opus-4-8"
  case "$item" in
    *'[model:opus]'*)   model="claude-opus-4-8" ;;
    *'[model:sonnet]'*) model="claude-sonnet-5" ;;
    *'[model:haiku]'*)  model="claude-haiku-4-5-20251001" ;;
  esac

  # Merging to main is opt-in per task and never the default.
  merge_note=""
  if wants_main_merge "$item"; then
    merge_note="

MERGE AUTHORIZED: Joon explicitly asked for this one to go straight to main. After
the work passes its checks, merge the branch into main and push. Do NOT open a draft
PR and wait. A reviewer runs before the merge and can still stop it. Everything else
in your rules still applies: never force-push, never touch .env, never merge anything
you were not asked to."
  fi

  run() {
    "$CLAUDE_BIN" -p "$(cat "$HQ/worker-prompt.md")
$merge_note

ITEM: $item" --model "$1" \
      --permission-mode acceptEdits \
      --allowedTools "$ALLOWED_TOOLS" 2>&1
  }

  gated() { printf '%s' "$1" | tail -5 | grep -qiE 'usage limit|out of (credits|usage)|rate.?limit|model.*(unavailable|not available|not found|retired)|invalid model'; }

  out=$(run "$model")
  used_model="$model"
  if gated "$out"; then
    case "$model" in
      claude-sonnet-5) fb="" ;;
      *)               fb="claude-sonnet-5" ;;
    esac
    if [ -n "$fb" ]; then
      log_event fallback "$item" "$model" "gated→$fb" 0 ""
      out=$(run "$fb"); used_model="$fb"
    fi
  fi
  if gated "$out"; then
    printf '\n=== ITEM (OUT OF LIMITS): %s ===\n%s\n' "$item" "$out" >> "$LOG"
    short=$(printf '%s' "$item" | sed -E 's/\[model:[a-z]+\] ?//' | cut -c1-110)
    ping "⏸ HQ — out of usage limits" "Paused on: $short — stays queued, retries next hour."
    log_event task "$item" "$used_model" LIMITS "$(( $(date +%s) - started ))" ""
    echo "LIMITS"; return
  fi
  printf '\n=== ITEM: %s ===\n%s\n' "$item" "$out" >> "$LOG"

  short=$(printf '%s' "$item" | sed -E 's/\[model:[a-z]+\] ?//' | cut -c1-110)
  pr=$(printf '%s' "$out" | grep -oE 'https://github\.com/[^ )]+/pull/[0-9]+' | tail -1)
  # The agent never merges. It signals readiness; the merge happens here, after review.
  ready_to_merge=$(printf '%s' "$out" | grep -q 'READY TO MERGE:' && echo yes || echo no)

  case "$out" in
    *"RESULT: DONE"*)
      status=DONE
      if [ "$ready_to_merge" = yes ] && [ -n "$pr" ]; then
        if review "$pr" "$item" premerge; then
          if gh pr merge "$pr" --squash --delete-branch >> "$LOG" 2>&1; then
            ping "✅ HQ — done, merged to main" "$short"
            log_event merge "$item" "$used_model" MERGED 0 "$pr"
          else
            ping "⚠️ HQ — merge failed" "$short — review passed but the merge didn't. PR is open: $pr"
            log_event merge "$item" "$used_model" MERGE_FAILED 0 "$pr"
          fi
        else
          ping "🛑 HQ — merge stopped by review" "$short — the reviewer found a blocker, so it was NOT merged. PR left open: $pr"
          log_event merge "$item" "$used_model" VETOED 0 "$pr"
        fi
      else
        ping "✅ HQ — finished a task" "$short${pr:+ → $pr}"
        review "$pr" "$item" pr
      fi
      log_finished "$short${pr:+ → $pr}"
      ;;
    *"RESULT: BLOCKED"*)
      status=BLOCKED
      ping "⚠️ HQ — stuck, parked it" "$short — marked ⚠️ in the queue. Delete that note to retry. Why: ~/hq/system/logs."
      ;;
    *)
      status=UNCLEAR
      ping "ℹ️ HQ — ran, unclear result" "$short"
      ;;
  esac
  log_event task "$item" "$used_model" "$status" "$(( $(date +%s) - started ))" "$pr"
  echo "$status"
}

count_done=0; prev=""
while [ "$count_done" -lt "$MAX_ITEMS" ]; do
  raw=$(ready_items | head -1)
  [ -z "$raw" ] && break
  item=$(printf '%s' "$raw" | strip_box)
  key=$(printf '%s' "$item" | cut -c1-80)
  [ "$key" = "$prev" ] && break     # no progress — don't loop on it this hour
  prev="$key"
  status=$(work_item "$item")
  count_done=$((count_done + 1))
  [ "$status" = "BLOCKED" ] && park_blocked "$raw"
  [ "$status" = "LIMITS" ] && break
done

log_event run_end "" "" OK "$count_done" ""

# --- janitor: dead worktrees are invisible until they're 500 MB ---
worktrees_live=0
for repo in "$HOME"/hq/projects/*/; do
  [ -d "$repo/.git" ] || continue
  git -C "$repo" worktree prune 2>/dev/null || true
  n=$(git -C "$repo" worktree list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
  worktrees_live=$(( worktrees_live + ${n:-0} ))
done

ready_count=$(ready_items | wc -l | tr -d ' ')
blocked_count=$(count '⚠️' "$QUEUE")
open_count=$(count '^-[[:space:]]\[[[:space:]]?\]' "$QUEUE")
printf '{"last_run":"%s","items_worked":%s,"ready":%s,"blocked":%s,"open":%s,"worktrees":%s}\n' \
  "$(now_iso)" "$count_done" "$ready_count" "$blocked_count" "$open_count" "$worktrees_live" > "$STATUS"

# --- commit HQ so every change the agent makes has history ---
# projects/ is gitignored — those are their own repos.
if [ "$AUTOCOMMIT" = 1 ] && [ -d "$HOME/hq/.git" ]; then
  if [ -n "$(git -C "$HOME/hq" status --porcelain)" ]; then
    git -C "$HOME/hq" add -A
    git -C "$HOME/hq" -c user.name="HQ worker" -c user.email="hq@localhost" \
      commit -q -m "hq: run $(date +%Y-%m-%d\ %H:%M) — worked ${count_done} item(s)" || true
    git -C "$HOME/hq" push -q origin HEAD 2>/dev/null || true
  fi
fi

exit 0
