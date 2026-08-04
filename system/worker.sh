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
FORYOU="$CONTROL/for-you.md"
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
ALLOWED_TOOLS='Bash(git:*),Bash(gh:*),Bash(npm:*),Bash(npx:*),Bash(node:*),Bash(bash scripts/verify.sh:*),Bash(mkdir:*),Bash(ls:*),Bash(mv:*),Bash(cp:*),Bash(mempalace:*),mcp__mempalace__mempalace_search'

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
# Dated so a stuck-for-a-week item can be escalated once instead of forgotten.
park_blocked() {
  today="$(date +%Y-%m-%d)" q_line="$1" /usr/bin/awk '
    BEGIN { line = ENVIRON["q_line"]; d = ENVIRON["today"]; done = 0 }
    !done && $0 == line && !index($0, "⚠️") {
      print $0 " — ⚠️ blocked " d " (details: ~/hq/system/logs) — delete this note to retry"
      done = 1; next
    }
    { print }
  ' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
}

# A ⚠️ item stuck 7+ days without you noticing gets exactly one follow-up ping,
# then an (escalated) tag so it never pings again on its own.
escalate_stale_blocked() {
  cutoff=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '-7 days' +%Y-%m-%d)
  grep -E '⚠️ blocked [0-9]{4}-[0-9]{2}-[0-9]{2}' "$QUEUE" | grep -v '(escalated)' | while IFS= read -r line; do
    d=$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    [ -z "$d" ] && continue
    if [[ "$d" < "$cutoff" ]]; then
      short=$(printf '%s' "$line" | strip_box | cut -c1-110)
      ping "⏰ HQ — stuck a week" "Still blocked since $d: $short"
      esc_line="$line" /usr/bin/awk '
        BEGIN { line = ENVIRON["esc_line"] }
        $0 == line { print $0 " (escalated)"; next }
        { print }
      ' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
      log_event escalate "$short" "" STALE_7D 0 ""
    fi
  done
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

# --- senses: once a day, read Gmail + Calendar and add to Joon's own to-do list ---
# These go straight into for-you.md because that list is his, not the agent's —
# nothing there is ever executed, so email can't reach anything that runs. The
# scan gets read-only Gmail/Calendar tools: no send, no reply, no delete.
if [ ! -f "$SENSES_STAMP" ] || [ -n "$(find "$SENSES_STAMP" -mmin +1200 2>/dev/null)" ]; then
  t0=$(date +%s)
  before_f=$(count '^-[[:space:]]\[' "$FORYOU")
  s_out=$("$CLAUDE_BIN" -p "$(cat "$HQ/senses-prompt.md")" \
    --model claude-sonnet-5 \
    --permission-mode acceptEdits \
    --allowedTools 'mcp__claude_ai_Gmail__search_threads,mcp__claude_ai_Gmail__get_thread,mcp__claude_ai_Google_Calendar__list_events,mcp__claude_ai_Google_Calendar__list_calendars' 2>&1)
  printf '\n=== SENSES ===\n%s\n' "$s_out" >> "$LOG"
  after_f=$(count '^-[[:space:]]\[' "$FORYOU")
  newf=$((after_f - before_f)); [ "$newf" -lt 0 ] && newf=0
  # Only mark the day done if the scan actually ran. On a spend/usage limit it
  # produces nothing, and stamping anyway would silently skip the next 20 hours.
  if printf '%s' "$s_out" | tail -5 | grep -qiE 'spend limit|usage limit|out of (credits|usage)|rate.?limit'; then
    log_event senses "" claude-sonnet-5 LIMITS "$(( $(date +%s) - t0 ))" ""
  else
    touch "$SENSES_STAMP"
    log_event senses "" claude-sonnet-5 "ADDED_${newf}" "$(( $(date +%s) - t0 ))" ""
    [ "$newf" -gt 0 ] && ping "📋 HQ — ${newf} thing(s) for you" "Added to your to-do list from your email and calendar: ~/hq/control/for-you.md"
  fi
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

# --- tester: a fresh session actually runs the project's checks on the branch ---
# Read-only, no comments posted anywhere. Feeds work_item()'s retry loop: FAIL sends
# the coding agent back with the concrete error; PASS lets the item proceed to review.
test_pr() {
  pr="$1"; item="$2"
  [ -z "$pr" ] && { echo "TEST: PASS"; return; }
  t0=$(date +%s)
  out=$("$CLAUDE_BIN" -p "$(cat "$HQ/test-prompt.md")

PR: $pr
TASK: $item" --model claude-sonnet-5 \
    --permission-mode acceptEdits \
    --allowedTools 'Bash(gh pr checkout:*),Bash(gh pr view:*),Bash(git status:*),Bash(npm:*),Bash(npm run:*),Bash(sh:*),Bash(bash:*),Bash(./scripts/verify.sh:*)' 2>&1)
  printf '\n=== TEST: %s ===\n%s\n' "$item" "$out" >> "$LOG"
  if printf '%s' "$out" | grep -q "TEST: FAIL"; then
    log_event test "$item" claude-sonnet-5 FAIL "$(( $(date +%s) - t0 ))" "$pr"
    echo "$out"
  else
    log_event test "$item" claude-sonnet-5 PASS "$(( $(date +%s) - t0 ))" "$pr"
    echo "TEST: PASS"
  fi
}

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

ITEM: $item
${2:-}" --model "$1" \
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

  # --- fresh test / fix loop: a second agent actually runs the checks. If they
  # fail, send the coder back with the concrete error, up to 2 more tries, before
  # this ever reaches a human review comment or Joon's phone.
  if printf '%s' "$out" | grep -q 'RESULT: DONE' && [ -n "$pr" ]; then
    attempt=1
    while [ "$attempt" -le 3 ]; do
      test_out=$(test_pr "$pr" "$item")
      printf '%s' "$test_out" | grep -q 'TEST: FAIL' || break
      [ "$attempt" -eq 3 ] && break
      fail_detail=$(printf '%s' "$test_out" | sed -n '/TEST: FAIL/,$p' | tail -n +2)
      fix_note="FIX REQUIRED — attempt $((attempt + 1))/3. The PR above ($pr) failed a fresh test run.
Do not restart the task; fix this specific failure on the existing branch, push, and
finish the same way as before.

Failure:
$fail_detail"
      out=$(run "$used_model" "$fix_note")
      printf '\n=== ITEM FIX (attempt %d): %s ===\n%s\n' "$((attempt + 1))" "$item" "$out" >> "$LOG"
      pr=$(printf '%s' "$out" | grep -oE 'https://github\.com/[^ )]+/pull/[0-9]+' | tail -1)
      attempt=$((attempt + 1))
    done
    if printf '%s' "$test_out" | grep -q 'TEST: FAIL'; then
      short=$(printf '%s' "$item" | sed -E 's/\[model:[a-z]+\] ?//' | cut -c1-110)
      ping "⚠️ HQ — failed testing 3x, parked it" "$short — marked ⚠️ in the queue. PR left open for you to look at: $pr"
      log_event task "$item" "$used_model" TEST_EXHAUSTED "$(( $(date +%s) - started ))" "$pr"
      echo "BLOCKED"; return
    fi
  fi

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

escalate_stale_blocked

# --- weekly spend check: how often did limits actually bite this week? ---
# Runs once a day (top of the hour it happens to catch), stamped so it doesn't
# repeat. Purely informational — it can't change your plan, only tell you.
SPEND_STAMP="$HQ/.last-spend-check"
if [ ! -f "$SPEND_STAMP" ] || [ -n "$(find "$SPEND_STAMP" -mmin +1200 2>/dev/null)" ]; then
  week_ago_epoch=$(( $(date +%s) - 604800 ))
  hits=0
  if [ -s "$RUNS" ]; then
    while IFS= read -r ts; do
      [ -z "$ts" ] && continue
      e=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo 0)
      [ "$e" -gt "$week_ago_epoch" ] && hits=$((hits + 1))
    done < <(grep -E '"status":"(LIMITS|gated)' "$RUNS" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')
  fi
  if [ "$hits" -ge 3 ]; then
    ping "📊 HQ — usage limits hit ${hits}x this week" "Tasks kept getting paused on limits. Logs: ~/hq/system/logs"
  fi
  touch "$SPEND_STAMP"
  log_event spend_check "" "" "HITS_${hits}" 0 ""
fi

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
# Only real task lines count as blocked — the queue's own instructions mention
# ⚠️ twice, and a bare grep reported "2 blocked" on an empty queue.
blocked_count=$(count '^-[[:space:]]\[.*⚠️' "$QUEUE")
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
