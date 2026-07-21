# MindSprint Product Backlog

Ideas that are valuable but deliberately not in the current milestone. Each
entry says what it is, why it matters, and what should trigger building it.
Maintained by the lead engineer; pruned when items ship or die.

## Student experience

- **Encouragement layer (redesigned, non-competitive).** The prototype's
  XP/coins/streaks were excluded because score-linked rewards incentivize
  speed-over-accuracy and contaminate measurement. A *deliberate* redesign —
  effort-based (sessions played, not scores), no leaderboards, no purchases —
  could drive the "want to return tomorrow" feeling safely. Trigger: pilot
  feedback showing motivation gaps.
- **Sound design + haptics.** Correct/wrong/complete audio cues and light
  haptic ticks (with per-school mute switch — classrooms!). Trigger: after
  the four playable modules exist; one polish pass across all of them.
- **Per-module tutorials ("how to play" demo round).** A practice round that
  emits NO measured events (explicitly excluded from metrics), so first-time
  confusion doesn't pollute a student's baseline. High measurement value.
- **Companion characters.** The prototype's module companions (Kora, Zephyr…)
  are charming; a light version could introduce each module's world. Pure
  presentation; no data impact.
- **Physical screen-reader pass on admin** (TalkBack/NVDA/VoiceOver) — the
  2026-07-21 audit verified semantic structure exists (shadcn/Radix
  defaults) but wasn't manually tested with an actual reader. Trigger:
  before first school pilot.

## Teacher intelligence

- **Student trend views.** Accuracy/reaction over sessions per module —
  "is this child improving?" is THE teacher question. Needs session volume;
  build after replay ships.
- **Class heatmap.** One screen: every student × every module, colored by
  recency and accuracy band. Answers "who haven't I assessed lately?"
- **Teacher notes UI** (schema already exists) attached to sessions/students.
- **Hesitation spotlighting in replay.** Auto-jump-to-longest-pause button;
  pauses are where the pedagogy lives.

## Admin / scale

- **CSV/PDF exports** (spec commitment; Phase 6).
- **Audit log viewer** (data exists since Phase 1).
- **Bulk student import** (CSV upload) — the "hundreds of students" essential.
- **Teacher invitation flow** (replaces manual dashboard+SQL onboarding).
- **Data-erasure admin flow** surfacing the audited delete RPC (DPDP; before
  pilot).

## Modules

- **Visual Search & Sequence Logic** (reserved; the last two of the core six).
- **Dedicated math_speed fixture** — pattern_recognition's fixture covers the
  shared question/tap contract, but math deserves its own canned session.
- **Prototype candidates: Color Symphony, Spatial Builder.** Different domains
  (auditory-visual binding; visuospatial construction). Evaluate against the
  core six before adding — no near-duplicates rule.
- **Math Speed v2 config options:** negative numbers, remainders, typed input
  for older students — config-gated, off by default.

## Measurement / platform

- **Per-question reaction times in canonical metrics v2** (math sessions have
  N stimuli; v1 uses only the first for reaction).
- **Adaptive difficulty engine** (on-device, server-reconciled) — after pilot
  baselines exist. The tier system and event data are ready for it.
- **Benchmarks** (class/school/grade aggregates as materialized views) — spec
  Phase 5; needs volume.
- **Insights Engine** (AI educational summaries; reserved name) — server-side
  only, never diagnostic, explicit guardrails. After benchmarks.
- **Offline roster/level caching** — seam exists in sync layer. Trigger:
  pilot connectivity failures.
- **Background upload via WorkManager** — trigger: stranded retry queues in
  pilot telemetry.
- **Retry-queue size cap + telemetry.**
- **Event-log compression for upload** (gzip the JSON payload) — trigger:
  sessions exceeding ~500 events (Focus Tap hard levels approach this).

## Operations

- **Release signing + Play Store listing + rename gate** (MindSprint name
  checks: Play availability, domain, trademark) — before first pilot.
- **Windows/macOS desktop builds** (need VS C++ workload / macOS runner).
- **Fix local Docker Desktop** (Inference Manager crash) — restores local
  pgTAP loop; currently CI covers it.
- **Sentry-style crash reporting** — evaluate against the no-third-party-SDK
  privacy rule; self-hosted or Supabase-native alternatives preferred.
