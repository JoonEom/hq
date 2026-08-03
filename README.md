# HQ

Joon's headquarters. One folder for everything he's building, plus the agent that works on it.

```
hq/
├── control/    ← what you write. Your inbox, queue, and to-dos.
├── system/     ← the agent. Its script, prompts, and logs.
└── projects/   ← your code. Each is its own git repo; HQ ignores them.
```

## How you use it

1. Write a note in `control/inbox.md` — plain English, one thought per line.
2. Every hour the agent reads it, turns notes into tasks in `control/queue.md`,
   works the top ones, and texts your phone.
3. It opens a draft pull request. You review and merge.

## The queue

A task is picked up when it's an open `- [ ]` line. It's skipped when it's:

| Marker | Meaning |
|---|---|
| `[YOU]` | yours to do — lives in `for-you.md`, never the queue |
| `(idea)` | a thought to revisit, not to build |
| `⚠️` | the agent got stuck. Delete the note to let it retry. |
| under `## Parked` / `## Done` | out of play |

Add `[model:haiku]`, `[model:sonnet]`, or `[model:opus]` to pick how much
thinking a task gets. Untagged means Opus.

## Merging straight to main

By default the agent opens a **draft PR and stops** — it never merges its own work.

To skip that for a small fix, say so in the note: *"fix the typo on the about page,
push to main"*. Then the agent pushes a branch, a reviewer reads the diff, and the
merge happens **only if that review is clean**. A blocker leaves the PR open and
pings you instead.

## What it will never do

Touch `.env` or secrets · force-push · delete anything outside the repo it's working
in · merge anything you didn't explicitly ask it to.

## Where things are recorded

- `system/runs.jsonl` — every event, append-only. The honest record of what happened.
- `system/status.json` — current state, rewritten each run.
- `system/logs/` — full transcripts.

The queue says what you *intended*; `runs.jsonl` says what actually *happened*.
Never write a fact here you could look up instead — that's how notes go stale.
