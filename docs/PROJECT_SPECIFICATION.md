# MindSprint â€” Project Specification

**Status:** FROZEN â€” approved official specification. No further architectural
changes unless a critical issue is discovered during implementation.
**Date:** 2026-07-18
**Name:** MindSprint (matches the Supabase project). Package identifier placeholder:
`com.mindsprint.app` — not final until Play Store availability, domain availability,
and trademark conflicts are verified before first release.

An Educational Cognitive Assessment Platform. The game is the interface; the analytics
platform is the product. Free forever â€” no paid features, no ads, no third-party SDKs.

Measures (educationally, never diagnostically): reaction time, recall time, decision
time, hesitation, accuracy, and learning progress for students, primarily under 15.

---

## 1. Product decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Usage model | **Teacher-supervised device.** Teacher logs in, selects student, hands device over. Students never have accounts. | Simplest, safest for under-15s; avoids child-account/consent infrastructure entirely. |
| Connectivity | **Online-required** to start a session; the in-progress session is never network-dependent. | Consciously accepted risk: no connectivity â†’ no new sessions. Seam left for later offline caching. |
| Devices | **Genuinely mixed** (Android tablets, Windows/macOS desktops). Android APK is the first shipping artifact. | Responsive design day one; device/platform/screen/input-method metadata recorded per session so benchmarks segment fairly. |
| Launch | **Pilot with 1â€“2 schools.** Multi-tenant data model from day one; lean admin tooling. | Fastest path to real classroom data. |
| Content | **Seeded + basic admin editing.** Complete tuned level set shipped as seeds; simple admin forms to tweak. Visual Assessment Builder is a roadmap item. | Content is 100% data-driven from day one; fancy editor later. |
| Difficulty | **Fixed difficulty in early phases.** Adaptive difficulty designed later against real pilot data; data model supports it now. | Adaptive difficulty contaminates measurement comparability before baselines exist. |
| Monetization | **None, ever.** | Free product. Also strengthens child-privacy posture: nothing but Supabase touches the network. |

## 2. Core architectural principle: event sourcing for sessions

Assessment sessions are fully event-sourced. Roster and content management are plain
CRUD (event-sourcing school administration adds complexity for zero measurement value).

```
Student plays assessment
  â†’ events recorded locally (monotonic clock)
  â†’ client computes PROVISIONAL metrics (instant result screen)
  â†’ complete session uploaded (atomic, idempotent RPC)
  â†’ server validates session
  â†’ CANONICAL metrics generated asynchronously from raw events
  â†’ reports, benchmarks, replay â€” all projections of the event log
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
MindSprint/
â”œâ”€â”€ apps/
â”‚   â”œâ”€â”€ student/                  # Flutter app (Android APK first; Windows/macOS builds)
â”‚   â””â”€â”€ admin/                    # Next.js dashboard
â”œâ”€â”€ supabase/
â”‚   â”œâ”€â”€ migrations/               # SQL migrations â€” schema's single source of truth
â”‚   â”œâ”€â”€ seed/                     # Demo school, categories, media, starter levels
â”‚   â””â”€â”€ config.toml
â”œâ”€â”€ packages/
â”‚   â””â”€â”€ contracts/                # Versioned JSON Schemas: event taxonomy, level-config
â”‚                                 #   shapes, metric definitions + shared test fixtures
â”œâ”€â”€ docs/
â”‚   â”œâ”€â”€ PROJECT_SPECIFICATION.md  # This document
â”‚   â”œâ”€â”€ ARCHITECTURE_DECISIONS.md # Why each technology/pattern was chosen
â”‚   â”œâ”€â”€ ROADMAP.md                # Phases and deferred features
â”‚   â”œâ”€â”€ CHANGELOG.md
â”‚   â””â”€â”€ specs/                    # Detailed per-phase designs as they are written
â”œâ”€â”€ tools/                        # Type generation, seed scripts, fixture runners
â””â”€â”€ README.md
```

`packages/contracts/` is the keystone: the Dart client and the Postgres metric engine
are both implementations of those schemas, and CI runs the same fixtures against both.

## 4. Flutter app architecture (apps/student)

Feature-first Clean Architecture; each feature has `presentation/`, `domain/`, `data/`.

```
lib/
â”œâ”€â”€ core/
â”‚   â”œâ”€â”€ di/            # Riverpod providers as the DI container
â”‚   â”œâ”€â”€ router/        # go_router; session routes are kiosk-lock-guarded
â”‚   â”œâ”€â”€ theme/         # Material 3, child-friendly, large touch targets
â”‚   â”œâ”€â”€ timing/        # TimingService â€” monotonic Stopwatch, the app's most
â”‚   â”‚                  #   important component
â”‚   â””â”€â”€ errors/
â”œâ”€â”€ data/
â”‚   â”œâ”€â”€ local/         # Drift (SQLite): event store + upload retry queue
â”‚   â””â”€â”€ remote/        # Supabase client wrapper
â”œâ”€â”€ features/
â”‚   â”œâ”€â”€ auth/          # Teacher login (email/password) + teacher PIN
â”‚   â”œâ”€â”€ roster/        # School â†’ Class â†’ Student selection (online-fetched)
â”‚   â”œâ”€â”€ session/       # Lifecycle: teacher-confirm â†’ run â†’ result â†’ return to roster
â”‚   â”œâ”€â”€ assessments/
â”‚   â”‚   â”œâ”€â”€ engine/    # AssessmentModule contract + registry + event recorder
â”‚   â”‚   â”œâ”€â”€ memory_recall/
â”‚   â”‚   â””â”€â”€ math_speed/
â”‚   â”œâ”€â”€ results/       # Provisional metric computation + instant result screen
â”‚   â””â”€â”€ sync/          # upload_session RPC, retry queue, pending badge
â””â”€â”€ main.dart
```

Key decisions:
- **Riverpod** for DI + state (one tool, compile-safe, testable without widgets).
- **TimingService:** monotonic `Stopwatch` started at session start. Every event stores
  `t_ms` (ms since session start â€” immune to wall-clock jumps) plus one wall-clock
  anchor at session start. Input timestamps come from pointer-event data, not frame
  callbacks. Honest accuracy: Â±10â€“20 ms across devices (touch sampling 60â€“120 Hz,
  ~16 ms frames) â€” fine for educational differences of hundreds of ms; device metadata
  makes comparisons segmentable.
- **AssessmentModule plug-in contract:** each module accepts a level config, renders
  its UI, emits typed events to the recorder, signals completion. Registry maps
  `module_key â†’ implementation`. New modules touch no existing code. Honest limit:
  a new module still requires an app update; the contract eliminates touching tested
  code, not releases.
- **Kiosk/session lock:** back navigation trapped during sessions; exit requires the
  teacher's PIN. A **teacher-confirmation dialog** (student name) precedes every
  session â€” prevents recording under the wrong classmate on a shared tablet.
- **Lifecycle honesty:** `app_backgrounded`/`app_foregrounded` are recorded; an
  interrupted session is flagged â€” reaction times across an interruption are untrusted.

## 5. Next.js admin architecture (apps/admin)

App Router, Server Components by default, shadcn/ui + Tailwind, Supabase SSR auth.
**No service-role key anywhere in the app** â€” every query runs as the logged-in user
through RLS.

```
app/
â”œâ”€â”€ (auth)/login/
â””â”€â”€ (dashboard)/
    â”œâ”€â”€ overview/       # Recently finished Â· needs review (invalid/flagged sessions)
    â”œâ”€â”€ schools/  classes/  teachers/  students/     # Roster CRUD
    â”œâ”€â”€ content/        # Categories, items, levels, media library (basic forms)
    â”œâ”€â”€ sessions/       # List â†’ detail â†’ replay
    â”œâ”€â”€ reports/        # Trends, benchmarks
    â””â”€â”€ settings/
components/             # shadcn/ui composites
lib/supabase/           # server + browser clients
lib/queries/            # ALL data access isolated here â€” pages never query inline
types/                  # supabase gen types output
```

Session replay: client component fetching ordered events, reconstructing the assessment
on a timeline (play/pause/scrub). Pure projection; no stored replay data.

Deferred deliberately: **Live Sessions** (needs Realtime presence streaming during
assessments, contradicting upload-at-end; roadmap item).

## 6. Database schema (Supabase / PostgreSQL)

**Identity & tenancy**
- `schools` Â· `classes` (â†’ school) Â· `students` (â†’ school, class; full name, roll
  number, optional birth *year* only â€” deliberate PII minimum; no email/photo/DOB)
- `profiles` (1:1 `auth.users`) Â· `user_roles` (user, role: `super_admin |
  school_admin | teacher`, school scope) â€” **the single table every permission check
  reads** Â· `teacher_classes`

**Content (data-driven, versioned)**
- `assessment_modules` (module_key, name, enabled). Four modules, each
  measuring a DIFFERENT cognitive ability (product rule: no near-duplicates):
  | module_key | Name | Measures | Ships |
  |---|---|---|---|
  | `memory_recall` | Memory Recall | Visual working memory, recall speed | Phase 2 |
  | `math_speed` | Mathematics Speed | Numerical processing, calculation speed | Phase 3 |
  | `attention_focus` | Focus Tap | Selective attention, response inhibition, processing speed (go/no-go: tap targets, withhold on distractors; commission errors = inhibition failures, omission errors = attention lapses) | Phase 5+ |
  | `pattern_recognition` | Pattern Detective | Fluid reasoning, logical pattern recognition (complete visual sequences: AB/ABC/AABB/ABB/mirror rules) | Phase 5+ |
  All four consume the same event log, `tap_registered`/`answer_submitted`
  payloads, and canonical-metrics pipeline — no engine changes per module.
- **Difficulty tiers (product decision 2026-07-18):** every module ships
  three predefined tiers — `easy` (slower pace, fewer items, longer thinking
  time), `medium` (balanced), `hard` (faster pace, more items/distractors,
  reduced display time). The tier is a `difficulty_tier` enum on `levels`
  used for selection and fair benchmarking; every actual knob lives in the
  level-version config JSON, validated by that module's contract schema —
  no tier values are hardcoded anywhere.
- `media_assets` (type: image/icon/audio/animation, storage path, uploaded_by,
  metadata) â€” the Media Library; `category_items` reference assets, never raw paths
- `categories` Â· `category_items` (label + media_asset ref)
- `levels` (module_key, name, difficulty rank, enabled) with **`level_versions`**
  (immutable config-JSONB snapshots, validated against contracts). Editing a level
  creates a new version; sessions reference the exact `level_version_id`.

**Event-sourcing core**
- `sessions` â€” client-generated UUID (idempotency), student/teacher/class/school,
  module_key, level_version_id, device metadata JSONB (platform, model, screen,
  input method, app version), `event_schema_version`, status
  (`uploaded â†’ validated | invalid`), provisional metrics JSONB (drift audit),
  interruption flag.
- `session_events` â€” (session_id, seq, event_type, t_ms, payload JSONB).
  **Range-partitioned by month from the first migration.** Unique (session_id, seq);
  inserts idempotent (ON CONFLICT DO NOTHING). Immutable by grant, not convention.
  Event payloads record what was actually displayed (item IDs, labels, positions) â€”
  replay is reproducible even if content is later edited or deleted.
- `session_metrics` â€” canonical projections: (session_id, `metrics_version`,
  computed_at, typed columns for headline metrics + JSONB for the rest).
  Recomputable from events by bumping metrics_version.

**Supporting**
- `teacher_notes` Â· `audit_logs` (actor/action/before/after for every admin mutation
  and every deletion) Â· benchmark aggregates as materialized views on a schedule.

**Platform operations**
- `app_versions` (id, version, minimum_supported_version, release_notes, released_at).
  At teacher login the app compares itself against the latest row's
  `minimum_supported_version`; too-old clients are blocked with an update prompt.
  (Which version generated a given session is already recorded on the session row.)
- `feature_flags` (key, enabled, description) â€” server-side kill-switch and staged
  rollout for shipped code (e.g. `maths_module`, `session_replay`,
  `benchmark_engine`, `adaptive_difficulty`). Fetched at login/session start.
  Honest limit: a flag can only toggle code already present in the installed app.

**Decoupled metric computation:** the upload RPC only inserts and marks the session
`pending`. A `pg_cron` sweep runs `compute_session_metrics()` â€” a whole class
finishing at once queues instead of spiking upload latency.

## 7. Authentication & permissions

- Teachers/admins: Supabase Auth email+password. **Students: no accounts, ever.**
- Custom access token hook stamps `role` + `school_id` from `user_roles` into the JWT;
  RLS policies check claims directly.
- RLS matrix: teacher â†’ rows scoped to assigned classes' school; school_admin â†’ their
  school; super_admin â†’ all. `session_events`: insert-only by the owning teacher.
- Deletion of student data happens **only** through an audited `SECURITY DEFINER`
  function â€” also the DPDP data-erasure path.
- The kiosk lock is the boundary between a curious child and the teacher's roster.

## 8. Analytics pipeline

**Event taxonomy** (versioned JSON Schema in contracts): session lifecycle
(`session_started/completed/aborted`, `pause_started/ended`,
`app_backgrounded/foregrounded`) Â· stimulus (`sequence_display_started`,
`item_displayed`, `sequence_hidden`, `question_displayed`) Â· input (`tap_registered`
with target/correctness/position, `answer_submitted`). Every event: monotonic `seq`,
`t_ms`, type, payload.

**Operational metric definitions v1** (stored versioned â€” these are project
definitions, not clinical standards):
- Reaction time: stimulus visible â†’ first tap
- Recall time: `sequence_hidden` â†’ first recall tap
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
3. Completion: provisional metrics â†’ instant result screen â†’ one atomic
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
  or ads; real erasure path; UI language is educational comparison only â€” no
  percentiles-against-norms, nothing diagnosis-shaped. **Never diagnose.**
- Storage: category/media images in a public-read bucket (non-sensitive); everything
  else private.

## 11. API structure

No custom API server â€” PostgREST through RLS is the API (near-zero infra cost for a
free product):
- Reads: direct PostgREST queries.
- Multi-step writes as Postgres RPCs: `upload_session(session, events[])`,
  `delete_student(...)` (audited cascade), `recompute_metrics(version)`.
- Types: `supabase gen types` for admin; Dart models hand-written against contracts
  and fixture-tested.
- Edge Functions: none initially; seam exists for export jobs if they outgrow Next.js
  server actions.

## 12. Reserved for the future (architecture-ready, zero implementation)

- **Assessment Builder** â€” visual level creation. Ready by construction: a level IS a
  contract-validated config document; the builder is a form UI that writes them.
- **Insights Engine** â€” future AI-generated educational summaries consuming canonical
  metrics. Name reserved; nothing built.
- **Live Sessions** dashboard panel (Realtime presence).
- **Adaptive difficulty** â€” on-device real-time engine (gameplay can never stall on a
  network call between trials), server reconciling authoritative results; designed
  after pilot data establishes baselines.
- **Offline caching** of roster + levels (seam exists in the sync layer).
- Future modules: Pattern Recognition, Visual Search, Attention, Logic, Reaction,
  Color Recall, Shape Recognition, Sequence Recognition â€” each a new `AssessmentModule`
  implementation + registry entry.

## 13. Phase 1 scope (foundation only â€” no gameplay, no metrics, no reports)

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
