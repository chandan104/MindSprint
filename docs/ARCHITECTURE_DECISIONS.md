# Architecture Decision Records

Every major decision, with the reasoning that made it. When revisiting this project
months from now, start here. Format: context → decision → consequences.

---

## ADR-001: Flutter for the student app

**Context:** One codebase must ship on Android (primary — first artifact is an APK),
Windows, and macOS, with smooth animation and precise input timing for children.

**Decision:** Flutter.

**Why:** Single codebase across all three targets with native compilation; direct
access to pointer-event timestamps (needed for measurement); Material 3 built in;
mature tooling. Alternatives: React Native (weaker desktop story, JS bridge adds
timing jitter), native ×3 (triple the work).

**Consequences:** Adding a new assessment module requires an app release. Timing
accuracy is bounded by device input sampling (±10–20 ms) — acceptable and recorded.

## ADR-002: Supabase as the entire backend

**Context:** Free product, no revenue, needs auth + Postgres + storage + an API with
near-zero operating cost and no server to maintain.

**Decision:** Supabase (PostgreSQL, Auth, Storage, PostgREST, RLS). No custom API
server.

**Why:** RLS gives real database-enforced multi-tenancy; PostgREST eliminates an API
tier; Postgres functions handle atomic uploads and metric computation server-side;
generous free tier fits a pilot. Alternative (custom Node/Go API + managed Postgres)
adds an always-on server to secure and pay for, for no Phase-1 benefit.

**Consequences:** Business logic that must be trusted lives in SQL (RPCs, RLS,
compute functions) — tested via fixtures. Vendor coupling is mitigated because
everything is standard Postgres under the hood; migrations are plain SQL in-repo.

## ADR-003: Event sourcing for assessment sessions (hybrid metrics, "Option C")

**Context:** The platform fundamentally measures user interactions over time. Metrics
definitions will evolve; replay must always work; students need instant results.

**Decision:** The immutable event log is the single source of truth. The client
computes provisional metrics for the instant result screen; the server computes
canonical metrics asynchronously from raw events. Server always authoritative.
Reports, benchmarks, replay, and future features consume canonical metrics only.

**Why:** Pure server-side (Option A) delays the child's result screen on flaky Wi-Fi.
Pure client-side (Option B) lets metric definitions drift between Dart and the
dashboard and makes historical recomputation impossible. The hybrid costs one
duplicated formula set — held identical by a CI fixture drift-guard — and buys
instant feedback plus a fully recomputable analytics history.

**Consequences:** Two metric implementations to keep in sync (enforced by CI, not
discipline). `session_events` grows fast → partitioned by month from the first
migration. Metric computation is decoupled from upload via pg_cron so simultaneous
class-wide finishes don't spike latency.

## ADR-004: Teacher-supervised model — students never have accounts

**Context:** Users are children under 15, in India (DPDP Act: explicit
parental-consent rules for children's accounts).

**Decision:** Only teachers and admins authenticate. Students are data records. The
teacher logs in, confirms the student by name, and hands the device over; a kiosk
lock (PIN-gated exit, trapped back-navigation) protects the session.

**Why:** Child credentials would drag in consent management, password resets,
account recovery for minors — heavy infrastructure with no measurement value in a
supervised classroom. Minimal PII (name, roll number, optional birth year) keeps the
DPDP surface small.

**Consequences:** No at-home/unsupervised assessment (acceptable; classroom is the
product). Wrong-student risk on shared tablets mitigated by the mandatory
teacher-confirmation dialog before every session.

## ADR-005: Online-required connectivity model

**Context:** School Wi-Fi is unreliable; a full offline-first sync engine is a large
build.

**Decision:** Starting a session requires connectivity (fresh roster + levels). The
in-progress session never touches the network; completed sessions upload atomically
with a local retry queue.

**Why:** Chosen explicitly over offline-tolerant caching to keep Phase 1 small.
Accepted risk, stated plainly: a Wi-Fi outage blocks new sessions that day. The sync
layer keeps a clean seam (local Drift store already exists) to add roster/level
caching later without rearchitecting.

## ADR-006: Riverpod for DI and state management

**Decision:** Riverpod providers serve as both the dependency-injection container and
state management.

**Why:** One tool instead of two (vs get_it + bloc/provider); compile-safe; every
dependency overridable in tests without widget scaffolding — essential for testing
the timing/recording pipeline headlessly.

## ADR-007: Drift (SQLite) for local persistence

**Decision:** Drift for the on-device event store and upload retry queue.

**Why:** Typed, migration-capable SQLite; transactional batch writes (events flush
every ~500 ms without blocking gameplay); queryable retry queue. Alternatives: Hive
(no relational queries, weaker integrity), raw sqflite (no type safety).

## ADR-008: Monorepo

**Decision:** One repository: `apps/student`, `apps/admin`, `supabase/`,
`packages/contracts`, `docs/`.

**Why:** Migrations live next to the code that depends on them; the contracts package
(event schemas, level-config schemas, metric definitions, shared fixtures) must be
consumed by both apps and CI — impossible to keep honest across repos; one git
history for one product built by one team.

## ADR-009: Versioning strategy — reproducibility by construction

**Decision:** Three mechanisms instead of version columns on every table:
1. **Event payloads are self-contained** — they record what was actually displayed
   (item IDs, labels, positions). Replay never queries content tables; old sessions
   reproduce even if content is edited or deleted.
2. **Levels are append-only** — `level_versions` holds immutable config snapshots;
   editing creates a new version; sessions reference the exact version.
3. **`metrics_version` + `event_schema_version`** cover scoring logic and event
   taxonomy evolution; history is recomputable by bumping metrics_version.

**Why:** Versioning categories/items/rules individually adds joins and bookkeeping
without strengthening the guarantee the three mechanisms already provide.

## ADR-010: "Assessment Modules", plug-in contract

**Decision:** Assessment types are **modules** implementing one contract: accept a
level config, render UI, emit typed events, signal completion. A registry maps
`module_key → implementation`.

**Why:** Future modes (Pattern Recognition, Visual Search, Attention, …) plug in
without modifying the engine, recorder, sync, or any existing test. Honest limit: in
a compiled app, a new module still requires an app update — the contract eliminates
touching tested code, not shipping releases.

## ADR-011: Single `user_roles` table for all permission checks

**Decision:** One `user_roles` table (user, role, school scope) is the sole source
for authorization. A custom access-token hook stamps role + school into the JWT;
every RLS policy reads those claims.

**Why:** Three roles checked three different ways is how permission bugs are born.
One table, one hook, one claim shape — auditable in one place.
