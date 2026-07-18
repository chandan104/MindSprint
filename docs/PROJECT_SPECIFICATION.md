# CogniPlay — Project Specification

**Status:** FROZEN — approved official specification. No further architectural
changes unless a critical issue is discovered during implementation.
**Date:** 2026-07-18
**Working name:** CogniPlay (renameable until Phase 1 begins)

An Educational Cognitive Assessment Platform. The game is the interface; the analytics
platform is the product. Free forever — no paid features, no ads, no third-party SDKs.

Measures (educationally, never diagnostically): reaction time, recall time, decision
time, hesitation, accuracy, and learning progress for students, primarily under 15.

---

## 1. Product decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Usage model | **Teacher-supervised device.** Teacher logs in, selects student, hands device over. Students never have accounts. | Simplest, safest for under-15s; avoids child-account/consent infrastructure entirely. |
| Connectivity | **Online-required** to start a session; the in-progress session is never network-dependent. | Consciously accepted risk: no connectivity → no new sessions. Seam left for later offline caching. |
| Devices | **Genuinely mixed** (Android tablets, Windows/macOS desktops). Android APK is the first shipping artifact. | Responsive design day one; device/platform/screen/input-method metadata recorded per session so benchmarks segment fairly. |
| Launch | **Pilot with 1–2 schools.** Multi-tenant data model from day one; lean admin tooling. | Fastest path to real classroom data. |
| Content | **Seeded + basic admin editing.** Complete tuned level set shipped as seeds; simple admin forms to tweak. Visual Assessment Builder is a roadmap item. | Content is 100% data-driven from day one; fancy editor later. |
| Difficulty | **Fixed difficulty in early phases.** Adaptive difficulty designed later against real pilot data; data model supports it now. | Adaptive difficulty contaminates measurement comparability before baselines exist. |
| Monetization | **None, ever.** | Free product. Also strengthens child-privacy posture: nothing but Supabase touches the network. |

## 2. Core architectural principle: event sourcing for sessions

Assessment sessions are fully event-sourced. Roster and content management are plain
CRUD (event-sourcing school administration adds complexity for zero measurement value).

```
Student plays assessment
  → events recorded locally (monotonic clock)
  → client computes PROVISIONAL metrics (instant result screen)
  → complete session uploaded (atomic, idempotent RPC)
  → server validates session
  → CANONICAL metrics generated asynchronously from raw events
  → reports, benchmarks, replay — all projections of the event log
```

Invariants:
- Raw event logs are **immutable** once uploaded (no UPDATE/DELETE granted to anyone).
- Canonical metrics are **always derived from raw events**, never manually edited.
- Session replay reconstructs the assessment **entirely from the event log**.
- All downstream consumers (reports, benchmarks, future adaptive difficulty, future
  Insights Engine) consume canonical metrics.
- If provisional and canonical metrics differ, **the server version is authoritative**.
  Provisional values are retained on the session row for drift auditing.

## 3. Monorepo structure

```
cogniplay/
├── apps/
│   ├── student/                  # Flutter app (Android APK first; Windows/macOS builds)
│   └── admin/                    # Next.js dashboard
├── supabase/
│   ├── migrations/               # SQL migrations — schema's single source of truth
│   ├── seed/                     # Demo school, categories, media, starter levels
│   └── config.toml
├── packages/
│   └── contracts/                # Versioned JSON Schemas: event taxonomy, level-config
│                                 #   shapes, metric definitions + shared test fixtures
├── docs/
│   ├── PROJECT_SPECIFICATION.md  # This document
│   ├── ARCHITECTURE_DECISIONS.md # Why each technology/pattern was chosen
│   ├── ROADMAP.md                # Phases and deferred features
│   ├── CHANGELOG.md
│   └── specs/                    # Detailed per-phase designs as they are written
├── tools/                        # Type generation, seed scripts, fixture runners
└── README.md
```

`packages/contracts/` is the keystone: the Dart client and the Postgres metric engine
are both implementations of those schemas, and CI runs the same fixtures against both.

## 4. Flutter app architecture (apps/student)

Feature-first Clean Architecture; each feature has `presentation/`, `domain/`, `data/`.

```
lib/
├── core/
│   ├── di/            # Riverpod providers as the DI container
│   ├── router/        # go_router; session routes are kiosk-lock-guarded
│   ├── theme/         # Material 3, child-friendly, large touch targets
│   ├── timing/        # TimingService — monotonic Stopwatch, the app's most
│   │                  #   important component
│   └── errors/
├── data/
│   ├── local/         # Drift (SQLite): event store + upload retry queue
│   └── remote/        # Supabase client wrapper
├── features/
│   ├── auth/          # Teacher login (email/password) + teacher PIN
│   ├── roster/        # School → Class → Student selection (online-fetched)
│   ├── session/       # Lifecycle: teacher-confirm → run → result → return to roster
│   ├── assessments/
│   │   ├── engine/    # AssessmentModule contract + registry + event recorder
│   │   ├── memory_recall/
│   │   └── math_speed/
│   ├── results/       # Provisional metric computation + instant result screen
│   └── sync/          # upload_session RPC, retry queue, pending badge
└── main.dart
```

Key decisions:
- **Riverpod** for DI + state (one tool, compile-safe, testable without widgets).
- **TimingService:** monotonic `Stopwatch` started at session start. Every event stores
  `t_ms` (ms since session start — immune to wall-clock jumps) plus one wall-clock
  anchor at session start. Input timestamps come from pointer-event data, not frame
  callbacks. Honest accuracy: ±10–20 ms across devices (touch sampling 60–120 Hz,
  ~16 ms frames) — fine for educational differences of hundreds of ms; device metadata
  makes comparisons segmentable.
- **AssessmentModule plug-in contract:** each module accepts a level config, renders
  its UI, emits typed events to the recorder, signals completion. Registry maps
  `module_key → implementation`. New modules touch no existing code. Honest limit:
  a new module still requires an app update; the contract eliminates touching tested
  code, not releases.
- **Kiosk/session lock:** back navigation trapped during sessions; exit requires the
  teacher's PIN. A **teacher-confirmation dialog** (student name) precedes every
  session — prevents recording under the wrong classmate on a shared tablet.
- **Lifecycle honesty:** `app_backgrounded`/`app_foregrounded` are recorded; an
  interrupted session is flagged — reaction times across an interruption are untrusted.

## 5. Next.js admin architecture (apps/admin)

App Router, Server Components by default, shadcn/ui + Tailwind, Supabase SSR auth.
**No service-role key anywhere in the app** — every query runs as the logged-in user
through RLS.

```
app/
├── (auth)/login/
└── (dashboard)/
    ├── overview/       # Recently finished · needs review (invalid/flagged sessions)
    ├── schools/  classes/  teachers/  students/     # Roster CRUD
    ├── content/        # Categories, items, levels, media library (basic forms)
    ├── sessions/       # List → detail → replay
    ├── reports/        # Trends, benchmarks
    └── settings/
components/             # shadcn/ui composites
lib/supabase/           # server + browser clients
lib/queries/            # ALL data access isolated here — pages never query inline
types/                  # supabase gen types output
```

Session replay: client component fetching ordered events, reconstructing the assessment
on a timeline (play/pause/scrub). Pure projection; no stored replay data.

Deferred deliberately: **Live Sessions** (needs Realtime presence streaming during
assessments, contradicting upload-at-end; roadmap item).

## 6. Database schema (Supabase / PostgreSQL)

**Identity & tenancy**
- `schools` · `classes` (→ school) · `students` (→ school, class; full name, roll
  number, optional birth *year* only — deliberate PII minimum; no email/photo/DOB)
- `profiles` (1:1 `auth.users`) · `user_roles` (user, role: `super_admin |
  school_admin | teacher`, school scope) — **the single table every permission check
  reads** · `teacher_classes`

**Content (data-driven, versioned)**
- `assessment_modules` (module_key, name, enabled)
- `media_assets` (type: image/icon/audio/animation, storage path, uploaded_by,
  metadata) — the Media Library; `category_items` reference assets, never raw paths
- `categories` · `category_items` (label + media_asset ref)
- `levels` (module_key, name, difficulty rank, enabled) with **`level_versions`**
  (immutable config-JSONB snapshots, validated against contracts). Editing a level
  creates a new version; sessions reference the exact `level_version_id`.

**Event-sourcing core**
- `sessions` — client-generated UUID (idempotency), student/teacher/class/school,
  module_key, level_version_id, device metadata JSONB (platform, model, screen,
  input method, app version), `event_schema_version`, status
  (`uploaded → validated | invalid`), provisional metrics JSONB (drift audit),
  interruption flag.
- `session_events` — (session_id, seq, event_type, t_ms, payload JSONB).
  **Range-partitioned by month from the first migration.** Unique (session_id, seq);
  inserts idempotent (ON CONFLICT DO NOTHING). Immutable by grant, not convention.
  Event payloads record what was actually displayed (item IDs, labels, positions) —
  replay is reproducible even if content is later edited or deleted.
- `session_metrics` — canonical projections: (session_id, `metrics_version`,
  computed_at, typed columns for headline metrics + JSONB for the rest).
  Recomputable from events by bumping metrics_version.

**Supporting**
- `teacher_notes` · `audit_logs` (actor/action/before/after for every admin mutation
  and every deletion) · benchmark aggregates as materialized views on a schedule.

**Platform operations**
- `app_versions` (id, version, minimum_supported_version, release_notes, released_at).
  At teacher login the app compares itself against the latest row's
  `minimum_supported_version`; too-old clients are blocked with an update prompt.
  (Which version generated a given session is already recorded on the session row.)
- `feature_flags` (key, enabled, description) — server-side kill-switch and staged
  rollout for shipped code (e.g. `maths_module`, `session_replay`,
  `benchmark_engine`, `adaptive_difficulty`). Fetched at login/session start.
  Honest limit: a flag can only toggle code already present in the installed app.

**Decoupled metric computation:** the upload RPC only inserts and marks the session
`pending`. A `pg_cron` sweep runs `compute_session_metrics()` — a whole class
finishing at once queues instead of spiking upload latency.

## 7. Authentication & permissions

- Teachers/admins: Supabase Auth email+password. **Students: no accounts, ever.**
- Custom access token hook stamps `role` + `school_id` from `user_roles` into the JWT;
  RLS policies check claims directly.
- RLS matrix: teacher → rows scoped to assigned classes' school; school_admin → their
  school; super_admin → all. `session_events`: insert-only by the owning teacher.
- Deletion of student data happens **only** through an audited `SECURITY DEFINER`
  function — also the DPDP data-erasure path.
- The kiosk lock is the boundary between a curious child and the teacher's roster.

## 8. Analytics pipeline

**Event taxonomy** (versioned JSON Schema in contracts): session lifecycle
(`session_started/completed/aborted`, `pause_started/ended`,
`app_backgrounded/foregrounded`) · stimulus (`sequence_display_started`,
`item_displayed`, `sequence_hidden`, `question_displayed`) · input (`tap_registered`
with target/correctness/position, `answer_submitted`). Every event: monotonic `seq`,
`t_ms`, type, payload.

**Operational metric definitions v1** (stored versioned — these are project
definitions, not clinical standards):
- Reaction time: stimulus visible → first tap
- Recall time: `sequence_hidden` → first recall tap
- Decision time: gap between consecutive answer taps
- Hesitation: any inter-tap gap > 3000 ms (fixed threshold v1; revisit with pilot data)
- Derived: mean/median/fastest/slowest reaction, longest pause, total idle, accuracy,
  error count, consistency (std-dev of reaction), fatigue trend (within-session slope),
  learning rate (across sessions)

**Drift guard:** identical fixture files (canned event logs with hand-verified
expected metrics) run against the Dart provisional engine AND the SQL canonical engine
in CI. Disagreement fails the build.

## 9. Synchronization

1. Session start requires connectivity (fresh roster + level fetch).
2. During session: events batch-write to Drift every ~500 ms and on lifecycle events.
   Gameplay never waits on network or disk.
3. Completion: provisional metrics → instant result screen → one atomic
   `upload_session` RPC.
4. Failure: payload persists in local retry queue; exponential backoff on app-resume
   and connectivity change; teacher sees a pending-uploads badge. Client UUIDs +
   upserts make retries safe.
5. After server ack, local session copies are briefly retained, then pruned.

## 10. Security & privacy

- App ships only the publishable key; **RLS is the security boundary.** Service-role
  key lives only in gitignored `.env` for migrations.
- Immutability by grant: no UPDATE/DELETE on `session_events` for any role; canonical
  metrics written only by the compute function; deletions only via audited RPCs.
- Child privacy (DPDP-aligned): minimal student PII; no third-party SDKs, analytics,
  or ads; real erasure path; UI language is educational comparison only — no
  percentiles-against-norms, nothing diagnosis-shaped. **Never diagnose.**
- Storage: category/media images in a public-read bucket (non-sensitive); everything
  else private.

## 11. API structure

No custom API server — PostgREST through RLS is the API (near-zero infra cost for a
free product):
- Reads: direct PostgREST queries.
- Multi-step writes as Postgres RPCs: `upload_session(session, events[])`,
  `delete_student(...)` (audited cascade), `recompute_metrics(version)`.
- Types: `supabase gen types` for admin; Dart models hand-written against contracts
  and fixture-tested.
- Edge Functions: none initially; seam exists for export jobs if they outgrow Next.js
  server actions.

## 12. Reserved for the future (architecture-ready, zero implementation)

- **Assessment Builder** — visual level creation. Ready by construction: a level IS a
  contract-validated config document; the builder is a form UI that writes them.
- **Insights Engine** — future AI-generated educational summaries consuming canonical
  metrics. Name reserved; nothing built.
- **Live Sessions** dashboard panel (Realtime presence).
- **Adaptive difficulty** — on-device real-time engine (gameplay can never stall on a
  network call between trials), server reconciling authoritative results; designed
  after pilot data establishes baselines.
- **Offline caching** of roster + levels (seam exists in the sync layer).
- Future modules: Pattern Recognition, Visual Search, Attention, Logic, Reaction,
  Color Recall, Shape Recognition, Sequence Recognition — each a new `AssessmentModule`
  implementation + registry entry.

## 13. Phase 1 scope (foundation only — no gameplay, no metrics, no reports)

1. Monorepo scaffold, docs committed, ADRs for the major decisions.
2. Supabase: linked project, initial migrations (all tables incl. partitioned
   `session_events`, `app_versions`, `feature_flags`, full RLS, roles, token hook),
   seed data (1 demo school, 2 classes, sample students, 2 modules, 3 categories with
   placeholder media, starter levels, initial app version row, default flags).
3. Flutter skeleton with real behavior for: teacher login, roster browse,
   teacher-confirm dialog, TimingService + event recorder + Drift store (proven by
   tests). Assessment screens stubbed.
4. Next.js skeleton: login, dashboard shell, lean CRUD for schools/classes/teachers/
   students.
5. CI: flutter analyze + tests; tsc + lint + tests; contract fixture runner wired.
6. Phase completion report with verification checklist and readiness score.

Subsequent phases: see ROADMAP.md.
