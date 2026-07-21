# MindSprint — Current Status

_Source of truth for "what exists right now." Updated every milestone.
Details live in PILOT_READINESS.md (gate checklist), PRODUCT_BACKLOG.md
(deferred ideas), ARCHITECTURE_DECISIONS.md (the why)._

**Last updated:** 2026-07-21 · **Branch:** `phase-1-foundation` · **Repo:**
github.com/chandan104/MindSprint · **Hosted project:** ddiqmwyavbvmqgbndwpa

## Shipped

- **4 playable modules:** Memory Recall, Mathematics Speed, Focus Tap,
  Pattern Detective. All fixture-guarded (Dart + SQL engines match).
- **Full pipeline:** monotonic timing → local event store → idempotent
  upload RPC → canonical SQL metrics (1-min sweep) → admin Session
  Replay, trends, observations, teacher notes.
- **Admin:** roster CRUD, sessions list/detail/replay, student reports,
  data erasure (audited RPC + typed-confirmation UI), teacher invites
  (self-serve join flow, no more manual SQL onboarding).
- **Security:** RLS everywhere, 10 pgTAP suites in CI, no third-party SDKs
  in the student app, minimal PII.

## APK build identity (fixed 2026-07-20 — see ADR entry)

Every release bumps `pubspec.yaml` version; login screen shows the build
fingerprint; Desktop APK filenames are versioned
(`MindSprint-v<version>-build<n>.apk`). Never ship
`MindSprint-debug.apk` (ambiguous name) again.

## In progress / next

See PILOT_READINESS.md "Pilot-blocking summary" for the live blocker list.

## Migrations (hosted, in order)

18 migrations applied through `20260721000001_teacher_invites`. Run
`supabase migration list --linked` to verify current sync state before
trusting this number — update it here after every push.
