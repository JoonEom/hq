# Joon's Queue — Claude's working list

This is **Claude's file** — you don't have to read or write here. You write in
**inbox.md**; anything that needs *you personally* lives in **for-you.md**. Every hour
Claude reads the inbox, turns each note into a task below, works up to 3 of them
(top-down), and pings your phone. If nothing's ready, it stays quiet — no work, no ping.

- **You write in `inbox.md`**, under the model section you want (Opus / Sonnet / Fable /
  Haiku / Me only / Not sure). Claude files each note here as a proper task.
- `[model:opus|sonnet|fable|haiku]` on a task = which model runs it. Every task gets
  one: from the inbox section you wrote under, or sized to the job when you didn't
  choose (small fix → small model, big build or hard problem → big model).
- Anything needing you (a purchase, Apple, accounts, a taste call) is routed to
  **for-you.md** and surfaced in the morning briefing — it never sits here.
- A task with a **⚠️ note is parked**: it hit a blocker, you got ONE ping, and the
  worker skips it from then on (no hourly retries). Delete the ⚠️ note — or drop an
  inbox note about it — to put it back in play.
- A daily briefing lands in **Claude/briefings/** every morning around 8.

---

## Kairo — the app (repo: ~/Downloads/kairo · verify: scripts/verify.sh · never push main)


## Kairo Webpage (repo: ~/Downloads/kairo-webpage · Vercel project: kairo-webpage)

  (nothing active — landing redesign + flip-postcards + stamp logo all merged; see Done. Reminder: this
   repo has NO auto-deploy — someone must pull main + run `vercel --prod` locally for changes to go live.)

## Money / new projects

- (nothing yet — drop ideas in inbox.md; a real project gets its own heading + repo path)

 

## Life / admin


## Done

- [x] 2026-07-18 — Homepage postcard marquee now auto-flips on staggered timers instead of
      tap-to-flip (kairo-webpage draft PR #7, branch feat/auto-flip-postcards). Each photo
      card flips on its own start offset + cadence (never in unison); removed the flip button,
      the "flip" hint chip, and the now-dead .mq-hint/.is-paused/cursor-pointer CSS. Respects
      prefers-reduced-motion. Resumed WIP a prior run left uncommitted in the working tree;
      `npm run build` passes. NEEDS JOON: eyeball the flip cadence, un-draft/merge PR #7 (I'm
      gate-denied from un-drafting), then pull main + `vercel --prod` locally — this repo has
      NO auto-deploy. Left untouched: unrelated untracked new postcard photos in public/postcards/.
- [x] 2026-07-17 — Wired Joon's new postage-stamp K logo across the kairo-webpage marketing
      site (draft PR #6, branch feat/new-logo-stamp-mark). The "new logo" is the redesigned
      stamp mark from the app (assets/brand/icon.svg — perforated bone stamp, hairline frame,
      Newsreader K), which replaced the old plain-K. Built a reusable inline-SVG KairoMark
      component (colors from the site's design tokens, K rendered via the --font-newsreader var
      so it matches the wordmark) and used it in: the header lockup, the footer, and the carousel
      card back (replacing the dashed-circle .mq-postmark placeholder). Favicon now app/icon.svg
      (the stamp), old app/icon.png removed — this is what shows in the browser tab / Google
      result. `npm run build` passes; rendered HTML confirms 14 marks + the SVG favicon link.
      NEEDS JOON: eyeball the mark's optical size/color on device and merge PR #6 (I'm gate-denied
      from un-drafting). This repo has NO auto-deploy — after merge, someone must pull main + run
      `vercel --prod` locally or the change won't go live (same gotcha as the /terms fix on
      2026-07-08).
- [x] 2026-07-10 — Removed the "Thursday" label from the reveal ceremony copy in
      ~/Downloads/kairo — swapped "THURSDAY" for "8:00 AM" in both
      components/RevealCeremony.tsx spots (LockedReveal's eyebrow + the ceremony's act-one
      eyebrow); app/(tabs)/index.tsx had no actual UI text to change, only comments. verify.sh
      passed. PR #33 (draft): https://github.com/JoonEom/kairo/pull/33
- [x] 2026-07-09 — Drafted the App Store + kairo-webpage screenshot shot list — saved to
      Claude/kairo-screenshot-shotlist.md in iCloud. 12 numbered shots, each naming the exact
      screen, the state/data to have on screen (no empty states), portrait vs landscape, and
      App Store vs kairo-webpage destination, plus a top section on Apple's current screenshot
      size/count requirements (6.9" class is the only required set, iPhone-only since
      supportsTablet is false) and a note that the camera-capture shot is the one genuinely
      landscape screenshot. Also flagged #12 (the exported shareable postcard) as the best
      asset to replace the site's current fake CSS postcard mockups in app/page.tsx's hero.

- [x] 2026-07-09 — Comments are now one thread per user-WEEK (not one per postcard), plus
      Instagram-style nested replies (kairo PR #31, draft, branch
      feat/week-scoped-comments-replies). New supabase/migrations/013_week_scoped_comments_and_
      replies.sql; rewrote lib/comments.ts; touched types/database.ts, components/CommentsSheet.tsx,
      components/CommentBar.tsx, components/PostcardDeck.tsx, app/archive-week.tsx. The schema move
      is comments.postcard_id → comments.(subject_user_id, week_id) + parent_comment_id. It's a
      BACKFILL, not a reset: every existing comment slides onto its postcard's (user, week) first,
      so a user's three per-card threads merge into that week's one thread ordered by created_at,
      and only then is postcard_id dropped (the old RLS policies name that column, so they get
      dropped first or the ALTER fails). The reveal gate is preserved by construction rather than
      re-derived: can_view_user_week(subject, week) is 006's can_view_postcard(pid) lifted from a
      postcard to the (user, week) pair — own week always, a friend's only once ends_at has passed.
      Requiring the pair to hold ≥1 postcard is what keeps an empty week from growing a thread and
      makes a week whose cards were all deleted stop showing one (comments no longer cascade off a
      postcard, so without that check they'd orphan). Delete widened from "any comment on your
      postcard" to "any comment on your week"; deleting a parent cascades to its replies via the
      self-FK and the confirm dialog says so BEFORE the thread visibly shrinks. Replies stop at one
      level like Instagram: a reply-to-a-reply re-parents onto the top-level comment and the client
      prefills "@handle " so it still names who it answers (cancelling takes back only that inserted
      handle, never typed text); a before-insert trigger is the backstop, since a CHECK constraint
      can't see other rows. archive-week now renders ONE CommentBar under the whole stack instead of
      one per card, and Home's deck count no longer changes as you swipe between a person's cards.
      Also taught the "DB is a step behind the app" path to catch a missing COLUMN (42703 — 006 ran,
      013 didn't) and not just a missing table (PGRST205). Both verify.sh gates pass (tsc --noEmit
      clean, expo export --platform ios bundles 1338 modules; verify.sh itself is still gate-denied,
      ✅ 2026-07-09: CONFLICTS RESOLVED, PR #31 is MERGEABLE/CLEAN again. main had merged #30
      (activity feed), which read comments.postcard_id — the column this branch drops. Merged main
      in: CommentBar keeps week-scoped props + the feed's autoOpen; archive-week's `focusPostcard`
      param became `openComments` (a week has one thread, so there's no card to single out);
      lib/activity.ts now filters on subject_user_id instead of joining through postcards.
      Migration renumbered 013 -> 015 (main already carries 012 + 014). Both verify gates pass.
      ⚠️ 015 IS DELIBERATELY NOT APPLIED: it DROPS comments.postcard_id, which the code on main
      still reads — applying before #31 merges breaks comments on your device. Merge #31 first,
      then apply. ⚠️ REMAINING FOR JOON: (a) apply
      015 by hand OR tell me to — it DROPS postcard_id, so read the backfill
      + `set not null` before running it; couldn't exercise it against the live DB (Supabase MCP
      execute_sql gate-denied), so backfill and trigger are review-verified, not round-tripped;
      (b) a simulator pass — comment from postcard 1, swipe to 3, same thread + same count; reply to
      a comment and to a reply; long-press-delete a parent that has replies. (c) RESOLVED — the #30
      conflict described here is fixed by the merge commit above; the comment notification now routes
      to the week's single thread and CommentBar's autoOpen hangs off that.
- [x] 2026-07-09 — Instagram-style activity feed added: a bell in Home's header opens a new
      /activity screen (kairo PR #30, draft, branch feat/activity-notifications-feed). New:
      app/activity.tsx, lib/activity.ts, hooks/useActivity.ts, supabase/migrations/
      012_activity_feed.sql; touched app/(tabs)/index.tsx (the bell + unseen dot),
      app/archive-week.tsx + components/CommentBar.tsx (deep-link target). The design call
      worth knowing: the feed is DERIVED, not stored — a notification is just an incoming
      pending friendship or someone else's comment on one of my postcards, and both rows
      already exist and are already RLS-gated, so there's no notifications table to write or
      fan out. The only thing migration 012 stores is whether you've LOOKED: a per-user
      watermark (notification_reads.last_seen_at = the created_at of the newest item present
      when you last opened the feed). Anything newer is unseen → the dot on the bell and on
      the row. Watermark is always written from an ITEM's server timestamp, never Date.now(),
      so a skewed phone clock can't mark not-yet-arrived items read; it never moves backwards;
      RLS is self-only; ON DELETE CASCADE from users means delete_account() (010) already
      carries it away. Opening the feed freezes which rows read as "new" during that render
      before moving the watermark, so the bell clears but the rows you haven't acted on stay
      marked for the visit. Routing: friend request → Friends tab; comment → archive-week for
      that postcard's week with the comment sheet already open on the right card (new
      focusPostcard param → new autoOpen prop on CommentBar). Deliberately did NOT put this in
      lib/notifications.ts as the item asked: that module calls setNotificationHandler at
      IMPORT time and needs the native module — which is exactly why _layout.tsx reaches it via
      a lazy try/caught dynamic import — and the bell renders on Home, so importing it there
      would pull expo-notifications into app startup and risk the outdated-Expo-Go crash for
      nothing. Local push stays there, the in-app feed is lib/activity.ts, each points at the
      other. Both verify.sh gates pass (ran tsc --noEmit + expo export directly; verify.sh
      itself is still gate-denied, its two gates aren't); node/gh/push all worked this run.
      ✅ 012 APPLIED 2026-07-09 via Supabase MCP apply_migration (011 was already live).
      notification_reads exists, RLS on, 3 own-row policies verified. The app is already writing
      watermarks to it (2 rows, both from real authenticated sessions minutes after it landed),
      and one row's last_seen_at is an item's timestamp from the day before rather than now() —
      the clock-skew guard works. Security advisor shows no new lint beyond the generic
      anon-policy warning every other table already carries (anon has no grant; a REST read as
      anon returns 401 permission denied, confirmed).
      ✅ 2026-07-09, Joon device-tested PR #30: "working fine" except the requester never heard
      back when their request was accepted. Fixed on the same branch (commit 8e999bd): third feed
      kind "X accepted your friend request", tapping it opens X's profile. Needed migration 014 —
      friendships only had created_at (when the request was SENT), so the item would have sorted
      to the request's date AND arrived pre-marked-read under the 012 watermark. 014 adds
      accepted_at, stamped by a BEFORE trigger rather than the client (the RLS update policy
      checks row values, not which columns were written, so a receiver could otherwise backdate
      the stamp under the requester's watermark and never raise a dot). 014 APPLIED to live DB +
      trigger verified in a rolled-back transaction: pre-stamped insert → NULL, forged accept →
      overwritten with now(), revert to pending → cleared. Both verify gates pass.
      ⚠️ ONE THING NEEDS JOON: (b) a simulator pass with a pending friend request + a comment on one of your
      postcards — check the dot, open the feed, confirm both rows navigate right, back out and
      confirm the dot cleared. The bell's optical centering against the wordmark and the dot's
      placement on the glyph are eyeball calls, in both light and dark mode. Could not exercise
      the two PostgREST reads against the live DB (Supabase MCP execute_sql gate-denied), so
      fetchCommentActivity's embedded filter (postcards!inner + .eq('postcard.user_id', me)) is
      verified by typecheck + bundle, not a round trip. Left untouched: the pre-existing
      untracked .agents/, .claude/skills/, skills-lock.json in the working tree.
- [x] 2026-07-09 — Landscape rule is now stated upfront, not just after a failed shutter tap
      (kairo PR #29, branch feat/landscape-hint-upfront) — ALREADY DONE AND MERGED to main by an
      earlier run that died before it could tick the queue; this run verified rather than redid it.
      Nothing was rebuilt, no new branch, no new PR. What's on main: app/camera.tsx renders a
      standing hint (phone-landscape glyph + "Turn your phone sideways" / "Postcards are
      landscape.") from the moment the screen opens in portrait, fading out once the phone turns;
      tapping the shutter upright now pulses that same hint instead of fading in a second overlay,
      so it's one element with one message. It's pointerEvents="none" and deliberately not
      counter-rotated (it only ever renders in portrait). app/(auth)/intro.tsx card 2 sub-copy now
      reads "Collect your week in postcards — shot with your phone held sideways." and
      FannedPostcardsIllustration carries a landscape-phone badge drawn with the repo's
      inverted-fill idiom (colors.text.primary disc, colors.background glyph) so both tokens invert
      together and it stays legible in dark mode — the exact bug class fixed in #25. Verified the
      merge commit (e82b827) is contained in origin/main and read the merged source of both files
      to confirm the strings and the badge actually render; local main is level with origin/main.
      Note main has since moved past PR #29's description: the tap-anywhere-viewfinder shutter was
      replaced by the volume-button shutter, so the old "Tap anywhere to shoot" hint the PR body
      mentions is gone — the standing upright hint is unaffected. ⚠️ STILL NEEDS JOON (carried over
      from the PR body, never done): a simulator pass — open the camera upright (hint should be up
      immediately), tap the shutter upright (hint pulses, no capture), rotate (hint fades), and look
      at intro card 2 in both light and dark mode. The animation timings and the badge's placement
      on the fan are eyeball calls that static analysis can't settle. Fourth time now that a queued
      item pointed at work whose PR was already merged.
- [x] 2026-07-09 — Locked-reveal copy on Home now reads "Sealed until you open the reveal."
      instead of "Sealed until everyone can see at once." (kairo PR #28, draft, branch
      copy/reveal-locked-copy) — matches the actual per-user open-gated behavior, not a
      group-wide moment. components/RevealCeremony.tsx:93 only, one line. Both verify.sh
      gates pass (tsc --noEmit clean, expo export --platform ios bundles 1337 modules);
      node/gh/push all worked this run.
- [x] 2026-07-08 — Sign-up with Apple now only asks for a handle (kairo PR #26, draft, branch
      feat/onboarding-handle-only-signup). Apple's name already reached profile.tsx — route param
      on first authorization, lib/pendingAppleName.ts (PR #16) on later attempts — it just landed
      in an editable NAME field the user had to read and tab past. Now: when a name is known the
      NAME field is a read-only row captioned "From your Apple ID", and the username input takes
      autoFocus so the keyboard opens on the only field that wants typing. One judgement call worth
      knowing: the field could NOT be hidden unconditionally. canContinue requires a non-empty name,
      and Apple returns fullName ONLY on the very first authorization for an Apple ID + app pair —
      so a reinstall that wipes the AsyncStorage stash mid-onboarding, an Apple ID that returns no
      name, and the __DEV__ anonymous sign-in (the PR #20 local testing loop) all arrive with
      nothing. Hiding the field would have stranded them behind a permanently disabled Continue
      button. So it's read-only when a name exists, editable when it doesn't; the Apple flow Joon
      described never types a name. Reading the stash is async, so the name resolves behind a brief
      spinner in the field's box rather than flashing an editable input that swaps to a read-only
      row. Both verify.sh gates pass (ran tsc --noEmit + expo export directly; verify.sh itself is
      still gate-denied, its two gates aren't). ⚠️ NEEDS JOON: a simulator pass on a genuinely fresh
      Apple ID (read-only name row + keyboard landing on the handle field) — the first-authorization
      behavior can't be replayed without a new Apple ID or revoking the app under Settings › Apple
      ID › Sign in with Apple. Heads-up for the next run: PR #25 (the next queue item's branch) is
      already MERGED — third time a queued item has named a stale PR branch.
- [x] 2026-07-08 — Dark-mode appearance UI + contrast bugs fixed (kairo PR #25, draft, branch
      fix/dark-mode-contrast). Note PR #18 was already MERGED, so its feature/dark-mode branch
      was stale — like the PR #21 case, fixes went on a fresh branch off main, not onto
      feature/dark-mode as the item assumed. (1) Settings › Appearance: the 3-way segmented
      Light/Dark/System picker (the one control that didn't look like the rest of Settings) is
      now a single "Dark mode" Switch row in a standard group card, structurally identical to
      the Notifications rows. "System" survives as behavior, not a button: the persisted mode
      is now 'light' | 'dark' | null, where null = never touched the toggle → follow the
      device, and an existing theme.json holding 'system' reads back as null, so nobody's saved
      preference resets. ThemeContext now exposes isDark/setDark instead of mode/setMode.
      (2) Root cause of the contrast bugs: PR #18 mechanically swapped static colors for theme
      tokens in every converted file — including files whose surfaces are FIXED. A theme token
      on a fixed surface inverts underneath it in dark mode. That IS the reported camera bug:
      the permission button is a hard-coded #FFFFFF pill but its label was colors.text.primary,
      which in the dark palette is near-white bone #F2EEE3 → white on white. Swept every
      converted file for both shapes of it (theme token as ink on a fixed surface; fixed surface
      hosting theme-reactive ink) and found 9 instances across 3 files. app/camera.tsx is
      reverted to a static stylesheet entirely — the whole screen is a permanently dark surface
      (black viewfinder, white chrome) in both modes, the same call PR #18 already made
      deliberately for RevealCeremony's overlay; camera just got missed. That one revert fixes 4
      bugs (permission label, initial spinner invisible on black, camera glyph near-invisible,
      capture spinner white-on-white inside the white shutter). RevealCeremony: cerPrint +
      cerLocation still theme-reactive inside the always-dark ceremony → dark-on-dark, pinned to
      fixed white. PostcardDeck: syncChipLabel (on a fixed dark chip) and photoLocation (over the
      photo itself) were colors.surfaceWhite = dark in dark mode → pinned white; flipHint's disc
      was fixed near-white under a theme-token glyph → made the disc theme-reactive so the pair
      inverts together. Deliberately left alone: the backgroundColor:text.primary +
      color:background inverted-fill button pairs across index/friends/create/profile/postcard-new
      — both tokens invert together so they stay readable by design, not bugs. Both verify.sh
      gates pass (ran tsc --noEmit + expo export directly: verify.sh itself is still gate-denied,
      its two gates aren't). ⚠️ NEEDS JOON: a simulator pass with Dark mode on — camera permission
      screen, a postcard front (sync chip + location caption + flip hint), and the reveal ceremony.
      The contrast fixes are static-analysis-verified, not eyeballed on device. Left untouched
      again: the unrelated uncommitted appleTeamId change in app.json's working tree.
- [x] 2026-07-08 — Account deletion actually works + onboarding re-triggers + Settings ›
      Help (kairo PR #24, draft, branch fix/account-deletion-onboarding-help). Note PR #21
      was already MERGED to main, so its branch was stale — fixes went on a fresh branch off
      main, not onto fix/signout-delete-account-flow as the item assumed. Root cause of the
      "Something went wrong" delete: the client call and RPC name were both FINE.
      delete_account() is SECURITY DEFINER so its body runs as the function owner (postgres),
      which isn't superuser on hosted Supabase — auth.users belongs to supabase_auth_admin, so
      `delete from auth.users` raises 42501 permission denied (the same class as the onboarding
      profile-save bug fixed in PR #23). plpgsql wraps the body in an implicit subtransaction,
      so that ONE unguarded statement rolled back the storage sweep and the public.users delete
      that had already run — everything undone, failed RPC, nothing deleted. This is exactly why
      PR #21's migration 009 changed nothing: it added the explicit public.users delete but left
      it ordered BEFORE the same fatal statement, so the rollback swallowed it too. Migration
      010_account_deletion_resilient.sql wraps the storage sweep and the auth-user delete each in
      their own exception block (broad catch — nothing there may abort the deletion); the
      public.users delete stays fatal since it's the row that IS the account and owns the ON
      DELETE CASCADE chain to postcards/friendships/comments. Supersedes 009, idempotent. That
      same fix resolves bug 2 for free — all routing keys off the profile row (index.tsx,
      signup.tsx afterAuth), and the old partial delete left it behind, so re-signup walked
      straight into the tabs; with it gone a returning Apple ID lands in onboarding even if the
      auth.users delete is denied (same uid, nothing attached). Bug 3: Settings › About › Help
      replays the intro cards via a `replay` param — last card closes back to Settings instead of
      continuing to invite, plus a Close button since the (auth) stack disables swipe-back.
      delete_account() now returns jsonb naming which steps ran (logged in __DEV__), and the
      silent "Please try again" alert — what let this hide across two PRs — now carries the
      server's own message. Both verify.sh gates pass (ran tsc --noEmit + expo export directly:
      verify.sh itself is gate-denied, its two gates aren't). ⚠️ TWO THINGS NEED JOON: (a) apply
      010 by hand in the Supabase SQL Editor — the app-side fix does NOTHING until it runs; (b) a
      simulator pass (delete → re-sign-in → expect onboarding; then Settings › Help). Could not
      verify against the live DB — Supabase MCP execute_sql was gate-denied — so the 42501
      diagnosis is static analysis of 008/009; it matches the symptom exactly and 010 is correct
      regardless of which error the auth delete raises. Also left untouched: an unrelated
      uncommitted `appleTeamId` change sitting in app.json's working tree (not part of this task,
      not committed).
- [x] 2026-07-08 — Fixed the live /terms 404 on the Kairo marketing site
      (https://kairo-webpage.vercel.app/terms). The page was fine in the repo — PR #2 had
      been merged to origin/main on GitHub — but this repo has no CI/CD (no GitHub Actions,
      no Vercel Git integration): production only ever gets deployed by running `vercel
      --prod` from a local checkout, and the local ~/Downloads/kairo-webpage main branch
      was still 2 commits behind (never pulled since PR #2 merged 2026-07-06), so the last
      production deploy predated the terms page. No code changes needed. Fixed by pulling
      origin/main (fast-forward, confirmed app/terms/page.tsx present + linked from the
      footer + content matches spec: account responsibility, content ownership,
      UGC community standards with a reporting path, termination, warranty/liability,
      change notice), `npm run build` passing, then `npx vercel --prod` from the synced
      checkout — aliased straight to the production domain. Verified live via `vercel curl`:
      full Terms of Use content now renders at /terms. Stashed one unrelated uncommitted WIP
      change to app/page.tsx copy (found sitting in the working tree, not part of this task)
      before building/deploying so it wouldn't go live accidentally — it's preserved in `git
      stash list` in that repo for whoever was mid-edit on it. Worth flagging to Joon: this
      repo's deploy model (manual `vercel --prod`, no git-triggered auto-deploy) means any
      future GitHub merge needs an explicit local pull + redeploy step, or it'll silently not
      go live like this one did.
- [x] 2026-07-08 — Sign Out / Delete Account flows fixed end-to-end (kairo PR #21, draft,
      branch fix/signout-delete-account-flow). Bug 1 (hang, no redirect): the only
      redirect-to-auth logic lived in app/index.tsx behind a useFocusEffect, so it only
      fired while the launch screen was focused — never when signing out from a deep
      screen like Settings. Added a global AuthGate in app/_layout.tsx that watches the
      session app-wide (useSegments) and replaces to '/' the moment it goes null on any
      protected route (self-healing; only acts on the signed-out direction so it can't
      double-navigate against index.tsx). Bug 2 (partial wipe: photo gone but
      profile/username survived): delete_account() (008) relied solely on `delete from
      auth.users` cascading to public.users, which no-ops if the fn owner lacks auth-schema
      privilege. Added migration 009_account_deletion_hardening.sql (idempotent create or
      replace) that deletes the public.users row EXPLICITLY — it owns the FK chain to
      postcards/friendships/comments (all ON DELETE CASCADE) — guaranteeing a full hard
      delete regardless of the auth.users outcome, then deletes the auth user. Also added
      lib/account.ts centralizing sign-out + delete with a full local-state wipe (offline
      postcard queue + photos, reveal-seen bookkeeping, cached Apple name) so nothing leaks
      into the next account on the device; theme/notification prefs kept intentionally. Both
      verify.sh gates pass (tsc --noEmit clean, expo export --platform ios bundles 1337
      modules); node/gh/push all worked this run. Two follow-ups need Joon: run migration 009
      by hand in the Supabase SQL Editor (after 008, like every migration here), and an
      on-device pass of both flows in the simulator.
- [x] 2026-07-07 — One-time pull-forward of the open week's reveal for TestFlight testing
      (kairo PR #19, draft, branch chore/testflight-reveal-pull-forward). Added
      supabase/dev/testflight_reveal_pull_forward.sql: updates ONLY the currently-open
      week's ends_at from Thursday 2026-07-16 15:00 UTC to Thursday 2026-07-09 15:00 UTC
      (8am PT), guarded so it's a no-op unless the open week is exactly in the expected
      state (starts_at <= now, ends_at > now, ends_at = 2026-07-16 15:00 UTC) — leaves
      historical weeks and the pg_cron rollover schedule (005) untouched, since the cron
      just reads ends_at and will roll over normally once the pulled-forward week ends.
      PR body flags clearly that this is one-time/test-only and the week needs to be
      reset back to 2026-07-16 after TestFlight testing, before the real launch. SQL-only
      change (no app/TS code touched), so verify.sh's tsc/expo gates don't apply; script
      itself hasn't been run against the live DB yet — Joon needs to run it by hand in the
      Supabase SQL Editor (same pattern as the other supabase/dev/*.sql scripts). node/gh/
      push all worked this run.
- [x] 2026-07-07 — Dark mode support added across the whole Kairo app (kairo PR #18, draft,
      branch feature/dark-mode). Theme infra (constants/colors.ts light/dark palettes,
      contexts/ThemeContext.tsx useTheme() hook, Light/Dark/System modes persisted via
      lib/settings.ts) plus a Settings toggle, built up over runs 1-6. This run (6) finished
      the last three files: app/camera.tsx, app/postcard-new.tsx, and
      components/RevealCeremony.tsx (LockedReveal + RevealCeremony + CeremonyCard) — same
      mechanical useTheme()/useMemo(createStyles) pattern as every other converted file.
      One deliberate design call made this run: RevealCeremony's dark theatrical overlay
      (INK/CREAM/MUTED/KAIRO_TINT) was aliased to colors.text.primary/colors.background,
      which only looked right in the light palette — dark mode inverts those same tokens
      (text.primary becomes light, background becomes dark), which would have flipped the
      reveal's "dark room" into a light one. Changed those four to fixed hex so the ceremony
      always renders dark regardless of the app's appearance setting; only the LockedReveal
      panel on Home stays theme-reactive. Every screen/component in the app is now
      dark-reactive except two deliberately-static ones (UserAvatar's initials discs,
      ShareWeekCard's shared export image) — both flagged in the PR body as taste calls for
      Joon (should exported/shared visuals ever follow the toggle, or always render in the
      brand's light/cream look?). Both verify.sh gates (tsc --noEmit, expo export --platform
      ios) pass; node/gh/push all worked this run. PR body updated with the full converted
      list. Remaining before merge — both need Joon directly, not scriptable here: a manual
      Light/Dark/System toggle pass in the simulator, and the ShareWeekCard/UserAvatar taste
      call above.
- [x] 2026-07-07 — First-time-login reveal gate bug fixed (kairo PR #17, draft, branch
      fix/first-login-reveal-gate). Root cause: the Thursday cadence isn't a runtime day
      check — it's baked into the weeks table's ends_at schedule (pg_cron rollover), so
      fetchLatestRevealedWeek()/hasUnseenReveal() just return the most-recently-ended week
      globally. A brand-new signup's local "last seen reveal" file is always empty, so they
      got swept into the "unlock this week's Kairo" ceremony for whatever week most recently
      ended app-wide — even if it ended before they signed up, on any day. The same
      globally-most-recent week also rendered as "LAST WEEK'S KAIRO" on Home instead of the
      null-case placeholder from PR #11, whose `!revealedWeek` guard assumed "any week has
      ever ended" = "this user has reveal history" (only true during the app's literal first
      week). Fix: scope fetchLatestRevealedWeek()/hasUnseenReveal() (lib/home.ts) to weeks
      that ended after the user's profile.created_at, threaded through useRevealedWeek
      (Home) and the Create tab's focus effect. Both verify.sh gates (tsc --noEmit, expo
      export --platform ios) pass; node/gh/push all worked this run.
- [x] 2026-07-07 — Apple sign-in name auto-fill persisted across incomplete onboarding
      (kairo PR #16, draft, branch feat/apple-signin-name-persist). Signup already forwarded
      Apple's given/family name into the profile screen via a route param, pre-filling it on a
      clean first run — the gap was that Apple only returns the name on the very first
      authorization, so if onboarding wasn't finished that session, later logins got no name and
      the field came up blank. Added lib/pendingAppleName.ts (AsyncStorage, keyed by user id) to
      stash the name as soon as it's captured in signup.tsx; profile.tsx falls back to it when
      the route param is empty and clears it once the profile row is created. Both verify.sh
      gates (tsc --noEmit, expo export --platform ios) pass; node/gh/push all worked this run.
- [x] 2026-07-07 — TestFlight double-transition bug after Apple sign-in fixed (kairo PR #15,
      draft, branch fix/apple-signin-double-transition). Root cause: app/index.tsx (the launch
      screen) is reached via router.push so it stays mounted underneath the sign-in screen; its
      plain useEffect watched the same session/profile auth state as signup.tsx's afterAuth() and
      fired its own router.replace() right alongside signup's explicit navigation — two competing
      navigations back-to-back, felt as a double swipe. Fixed by gating the launch screen's
      redirect effect with useFocusEffect (expo-router) so it only navigates while actually
      focused, leaving signup.tsx as the sole navigator right after sign-in. Both verify.sh gates
      (tsc --noEmit, expo export --platform ios) pass; node/gh/push all worked this run.
- [x] 2026-07-06 — Kairo launch-prep session with Joon (live, interactive). Consolidated the
      whole app repo to `main` only via PR #9: EAS build setup (eas.json build/submit profiles,
      react-dom pinned to 19.1.0 which fixed EAS's strict `npm ci`, `eas init` projectId),
      finalized App Store listing (docs/app-store-listing.md), export-compliance flag
      (ITSAppUsesNonExemptEncryption:false), the no-alpha app icon, the curated 10-prompt bank
      (supabase/migrations/007_seed_prompts.sql), and web/ removal. Deleted 9 stale branches +
      the landing-page worktree — this superseded the old scattered PRs #5 (docs/app-store-copy),
      #6 (chore/eas-app-store-prep, its icon fix carried over), #7 (remove-marketing-web, folded
      into #9) and #8 (docs/kairo-prompts). Proven EAS cloud simulator build is green; verify.sh
      passes throughout.
- [x] 2026-07-06 — Prompts live in Supabase: Joon ran 007_seed_prompts.sql + removed the
      non-curated 005 starter prompts; confirmed the pg_cron weekly rollover (005) is automatic
      and realigned the current week to Thursday 8am PT (2026-07-16 15:00 UTC).
- [x] 2026-07-06 — Brand mark on every surface: "K" postmark stamp on the in-app postcard back
      (PostcardDeck, kairo PR #10, merged), Newsreader-rendered K favicon on the marketing site
      (kairo-webpage app/icon.png, PR #1, merged), and merged the waiting Terms of Use page
      (kairo-webpage PR #2). App wordmark + shareable card already carried the mark. kairo-webpage
      cleaned to main-only.
- [x] 2026-07-06 — First-week Home reveal placeholder (kairo PR #11, merged): on first launch
      (no week revealed yet) Home was blank under the reveal; added a quiet "The reveal" heading +
      dashed postcard-shaped placeholder card. Scoped structurally to only the launch week (renders
      iff no revealed week exists — impossible after the first Thursday). Tested live by Joon in the
      simulator, including skipping the week forward to watch it hand off to a real reveal.
- [x] 2026-07-04 — Drafted short-film concepts for Kairo → Claude/kairo-short-film-ideas.md
      in iCloud. 5 full concepts + 3 quick-hits spanning the required angles (A24 narrative
      teaser "The Drop", Patagonia-style doc/vlog "One Week on the Island", Cotopaxi/Poler
      montage manifesto, postcard object-story, BeReal anti-performance piece), each with
      hook / Whidbey shots+locations / mission tie-back / teaser-vs-mission structure, plus a
      reference matrix, a recommended teaser+mission rollout, and digicam production notes. The
      through-line I leaned on: the grainy digicam look IS the anti-performance thesis. Non-code,
      docs-only.
- [x] 2026-07-04 — Copied the 20 draft Kairo prompts into iCloud as
      Claude/kairo-prompts.md (an exact copy of ~/Downloads/kairo/docs/kairo-prompts.md
      from PR #8 / branch docs/kairo-prompts) so Joon can view/edit them from his phone.
      Additive copy — the repo copy is untouched (no commit needed; file already lives on
      the branch). Docs-only, verify.sh not applicable.
- [x] 2026-07-04 — Created GitHub repo JoonEom/kairo-webpage (private) and pushed the local
      history to it as origin: main tracks origin/main, and the waiting docs/terms-of-use
      branch (bc87e9c) was pushed too. Repo: https://github.com/JoonEom/kairo-webpage.
      One loose end: `gh pr create` for the terms branch was gate-denied in this unattended
      run, so its draft PR isn't open — the branch is on the remote, so Joon can open it in one
      click at https://github.com/JoonEom/kairo-webpage/pull/new/docs/terms-of-use.
- [x] 2026-07-04 — Write 20 draft Kairo prompts → docs/kairo-prompts.md in ~/Downloads/kairo,
      draft PR #8 (branch docs/kairo-prompts). Matches the existing "find water" tone (short,
      lowercase, open-ended hint not instruction); themed on self-growth/small risk/new
      experience per the app's vibe. Flagged 3 of the 20 as leaning more emotionally
      vulnerable — worth a gut check on rollout order. Docs-only, verify.sh not applicable.
- [x] 2026-07-04 — Deleted the redundant marketing `web/` folder (index.html landing +
      privacy.html + README/.gitignore, plus the untracked .vercel link) from the app repo
      ~/Downloads/kairo — the site now lives standalone at ~/Downloads/kairo-webpage. Nothing
      in the app referenced it (git grep clean). Left Expo's `expo start --web` script and the
      `design/` mockups alone (not the marketing site). Both verify.sh gates pass (tsc --noEmit
      + expo export ios). Committed on branch `chore/remove-marketing-web` (47f96b1), pushed,
      draft PR #7.
- [x] 2026-07-04 — Prepped ~/Downloads/kairo for App Store builds — draft PR #6
      (branch chore/eas-app-store-prep). Added eas.json (development/preview/production
      build profiles, appVersionSource: "remote" so EAS manages iOS build numbers
      instead of manual app.json bumps). Checked app.json: bundle id (com.kairo.app),
      splash config, Android adaptive icons were all already correct. Found and fixed a
      real issue: assets/icon.png (the 1024x1024 App Store icon) was RGBA even though
      its source SVG is fully opaque — Apple/Xcode reject App Store icons with an alpha
      channel — re-encoded as RGB, pixel-identical (verified via pngjs, alpha was 255
      everywhere). tsc --noEmit and expo export --platform ios (verify.sh's two gates)
      both pass; node/npm/gh all worked this run. One step needs Joon directly and can't
      be scripted: `eas login && eas init` once (to populate extra.eas.projectId in
      app.json) before a real `eas build --profile production` will work — noted in the
      PR body.
- [x] 2026-07-04 — Added /terms to ~/Downloads/kairo-webpage (Next.js app/terms/page.tsx),
      next to /privacy — covers account responsibility, content ownership/license, App
      Store-required UGC community standards with a reporting/removal path (friends circle,
      not a public feed, but Apple still requires this for UGC apps), termination,
      warranty/liability, change notice. Linked from the footer and cross-linked with
      /privacy; privacy copy lightly tightened (dated bump, cross-link) — it was already
      concise, no bloat found. `npm run build` passes (node/npm/gh all present this run).
      Committed on branch `docs/terms-of-use` (bc87e9c) off main. Not pushed / no PR: this
      repo has no GitHub remote yet — that's the other queued item ("create kairo-webpage
      GitHub repo"); once that lands, push this branch and open the PR.
- [x] 2026-07-04 — Write the App Store listing copy → docs/app-store.md in ~/Downloads/kairo,
      draft PR #5 (branch docs/app-store-copy). Name/subtitle/keywords/promo/description all within
      Apple's char limits (counts noted, ▶ recommended + alternates), plus the non-copy App Store
      Connect fields review needs. Docs-only, so verify.sh (tsc + iOS bundle) doesn't apply.
- [x] 2026-07-04 — Rebuild the Kairo marketing website as its own standalone Next.js
      project at ~/Downloads/kairo-webpage — live at https://kairo-webpage.vercel.app
      (own Vercel project, ready for a custom domain). Explains the weekly Kairo
      (prompt) mechanic with a "Kairo in progress · find water" card + "Live your week"
      steps; all invite-only copy removed (CTA is now "Coming soon to the App Store");
      fully fluid layout that fits a 320px screen (the old postcard fan overflowed);
      privacy policy carried over at /privacy. Local git repo, no GitHub remote yet.
- [x] 2026-07-04 — Design an app icon/logo for Kairo and wire it into the app — done on
      branch `feat/app-icon` (6693d32). Mark: the Kairo "K" in Newsreader (the app's real
      serif — the brief's Fraunces was swapped out) in espresso #26241F on warm bone
      #F7F3EA with a hairline postcard-edge frame; splash = the "Kairo" wordmark matching
      app/index.tsx so the native splash dissolves into the launch screen. Canonical SVG
      sources in assets/brand/ + a generator (`npm run icons`, scripts/generate-icons.mjs)
      that renders PNGs with the app's own Newsreader TTFs. app.json fully wired:
      expo-splash-screen plugin config added (was absent) + Android adaptiveIcon bg fixed
      from Expo-default blue to bone. Sandbox has no node, so running the generator +
      verify/push/PR are handed off to Joon (for-you.md, steps in
      Claude/kairo-icon-handoff.md) — PNGs are placeholders until then; don't App-Store
      build before running it.
- [x] 2026-07-04 — Remove all test/seed data from the Kairo app — traced it to two
      places in the live Supabase project: the "Maya (test)" friend account
      (`supabase/dev/seed_friend.sql`) and a test Kairo prompt + week ("find water")
      seeded by `supabase/migrations/002_seed_test_data.sql`. Added
      `supabase/dev/cleanup_pre_launch.sql` to remove both in one guarded pass (won't
      touch a week that has real postcards). Committed on branch
      `cleanup/remove-test-seed-data` (a2ca3b3). No other test/demo data found
      elsewhere in the app source. Same sandbox limits as before (no node/gh, no push
      network) — verify/push/PR + actually running the SQL against the live DB are
      handed off to Joon at the top of for-you.md, full steps in
      `Claude/kairo-test-data-cleanup-handoff.md`.
- [x] 2026-07-04 — Pre-launch refactor/cleanup of the kairo repo — DONE + committed on branch
      `cleanup/pre-launch-refactor` (825ce61, tree clean). Removed dead `constants/strings.ts`,
      unused `getLastSyncError()`, empty `screens/`, stray root files; gitignored worktrees; added
      web/.gitignore. Full lib/component/hook export audit done — rest all in use, no console.logs/TODOs.
      The cleanup WORK is complete. Only the git delivery (verify.sh → push → draft PR) remains, and
      it's structurally impossible in this sandbox (no node/gh on PATH, gate denies node, push has no
      net/auth — confirmed across 6 runs). Delivery is now a human task owned by Joon at the TOP of
      for-you.md ("Ship the pre-launch cleanup, ~30s"), with copy-paste steps in
      Claude/kairo-cleanup-handoff.md. Closing here so it stops starving the other launch tasks.
- [x] 2026-07-03 — Inbox pipeline test: got your note, sent the phone ping ✅
- [x] 2026-07-03 — Landing page + privacy policy built → draft PR #1
- [x] 2026-07-03 — HQ system set up: queue + worker + daily briefing
