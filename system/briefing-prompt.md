Write Joon's daily briefing and save it to:
~/hq/control/briefings/<today YYYY-MM-DD>.md

Gather (skip anything unreachable without complaining about it):
1. Claude's queue (~/hq/control/queue.md):
   what got done since yesterday, what the worker will pick up next, any ⚠️ blocked items.
2. Joon's own to-dos (~/hq/control/for-you.md):
   every open `- [ ]` under "## To do" — these are the things waiting on Joon himself.
3. Kairo repo (~/Downloads/kairo): current branch, open PRs (`gh pr list`), anything
   uncommitted or unusual.
4. If Gmail / Google Calendar tools are available in this session: today's events and
   any important-looking unread email. If they aren't available, skip silently.
5. One concrete suggestion — the single highest-leverage thing for Joon today.

Under ~300 words, warm but direct. Structure:
**Today** / **Done since yesterday** / **Waiting on you** / **Suggestion**.

End your final message with exactly one line starting with:
BRIEF: <one-sentence phone-notification version, under 150 chars>
