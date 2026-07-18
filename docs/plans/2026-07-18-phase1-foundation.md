# Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the complete MindSprint foundation — monorepo, Supabase schema with RLS, Flutter skeleton with working teacher login/roster/timing/event-recording, Next.js admin skeleton with roster CRUD, and CI — with zero gameplay.

**Architecture:** Event-sourced sessions on Supabase/PostgreSQL (immutable partitioned event log, canonical metrics as projections — later phases), teacher-supervised Flutter client (Riverpod DI, Drift local store, monotonic TimingService), Next.js App Router admin running entirely through RLS. Per frozen PROJECT_SPECIFICATION.md — no architectural deviation without a critical-issue stop.

**Tech Stack:** Flutter (Dart 3.x), Riverpod, go_router, Drift, supabase_flutter · Next.js 15, React 19, TypeScript 5, Tailwind 4, shadcn/ui, @supabase/ssr · Supabase CLI, PostgreSQL 15+, pgTAP.

## Global Constraints

- Package identifier placeholder: `com.mindsprint.app` (Android `applicationId`, Windows/macOS bundle IDs). NOT final — rename gate before first release (Play Store / domain / trademark checks).
- Supabase project: `ddiqmwyavbvmqgbndwpa` (named MindSprint) at `https://ddiqmwyavbvmqgbndwpa.supabase.co`. Publishable key `sb_publishable_-77gBUKrqZytOOueQFEyEg_z5kYPXZT` (safe to embed). Service-role key and DB password: NEVER in git, chat, or app bundles — local `.env` only.
- No third-party SDKs, analytics, or ads in the student app. Only Supabase touches the network.
- Students never have auth accounts. Minimal student PII: full name, roll number, optional birth year.
- `session_events` immutable (no UPDATE/DELETE grants) and range-partitioned by month from the first migration that creates it.
- All timestamps in gameplay events: monotonic `t_ms` from TimingService; wall-clock only as a session-start anchor.
- Every admin mutation audited. UI copy is educational, never diagnostic.
- Versions below = latest stable known at plan date; Task 1/10/15 pin actual latest stable at install; completion report records the lockfiles.

---

## 1. Complete monorepo folder structure (end state of Phase 1)

```
mindsprint/
├── .github/workflows/ci.yml
├── .gitignore
├── README.md
├── docs/
│   ├── PROJECT_SPECIFICATION.md      (exists)
│   ├── ARCHITECTURE_DECISIONS.md     (exists)
│   ├── ROADMAP.md                    (exists)
│   ├── CHANGELOG.md
│   └── plans/2026-07-18-phase1-foundation.md   (this file)
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   │   ├── 20260718000001_identity_and_roles.sql
│   │   ├── 20260718000002_tenancy.sql
│   │   ├── 20260718000003_content.sql
│   │   ├── 20260718000004_sessions.sql
│   │   ├── 20260718000005_platform_ops.sql
│   │   └── 20260718000006_rls_policies.sql
│   ├── seed.sql
│   └── tests/                        # pgTAP: 01_schema.sql, 02_rls.sql, 03_immutability.sql
├── packages/contracts/
│   ├── README.md
│   ├── events/v1/                    # JSON Schemas: session_started.json, tap_registered.json, …
│   ├── levels/v1/                    # memory_recall.config.json, math_speed.config.json
│   ├── metrics/v1/definitions.md     # operational metric definitions (from spec §8)
│   └── fixtures/                     # canned event logs + expected metrics (trivial in P1)
├── tools/
│   └── validate-contracts.mjs        # ajv: fixtures validate against schemas (CI step)
├── apps/student/                     # Flutter (structure per spec §4; files in tasks below)
└── apps/admin/                       # Next.js (structure per spec §5; files in tasks below)
```

## 2. Flutter dependencies (apps/student/pubspec.yaml)

| Package | Version | Purpose |
|---|---|---|
| flutter_riverpod | ^3.0.1 | DI + state (ADR-006) |
| riverpod_annotation | ^3.0.1 | codegen annotations |
| go_router | ^16.2.0 | routing, kiosk guards |
| supabase_flutter | ^2.10.0 | auth + PostgREST client |
| drift | ^2.28.0 | local event store + retry queue (ADR-007) |
| drift_flutter | ^0.2.7 | platform DB setup |
| freezed_annotation | ^3.1.0 | immutable domain models |
| json_annotation | ^4.9.0 | event payload serialization |
| uuid | ^4.5.1 | client-generated session/event IDs |
| connectivity_plus | ^7.0.0 | online-required checks |
| flutter_secure_storage | ^9.2.4 | teacher PIN (hashed) |
| intl | ^0.20.2 | formatting |

Dev: riverpod_generator ^3.0.1 · drift_dev ^2.28.0 · build_runner ^2.7.0 · freezed ^3.1.0 · json_serializable ^6.11.0 · mocktail ^1.0.4 · flutter_lints ^6.0.0 · flutter_test (SDK).

Flutter SDK: latest stable (≥3.35 / Dart ≥3.9), pinned in `.fvmrc`-style note in README + CI.

## 3. Next.js dependencies (apps/admin/package.json)

| Package | Version | Purpose |
|---|---|---|
| next | ^15.4 | App Router framework |
| react / react-dom | ^19.1 | UI |
| typescript | ^5.9 | types |
| tailwindcss | ^4.1 | styling |
| @supabase/supabase-js | ^2.53 | client |
| @supabase/ssr | ^0.7 | cookie-based SSR auth |
| zod | ^4.0 | form/query validation |
| lucide-react | latest | icons |
| shadcn/ui (CLI-installed) | latest | button, input, table, dialog, form, card, sonner, dropdown-menu, label, select |

Dev: eslint ^9 + eslint-config-next · vitest ^3 · @testing-library/react ^16 · @testing-library/jest-dom · jsdom · prettier.

## 4. Environment variables

| Where | File (gitignored) | Committed example | Contents |
|---|---|---|---|
| Flutter | `apps/student/env/dev.json` (used via `--dart-define-from-file`) | `env/dev.json.example` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| Admin | `apps/admin/.env.local` | `.env.example` | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| Supabase CLI | interactive login; DB password entered at `link` time, never stored | — | — |

Root `.gitignore` covers: `env/*.json`, `.env*`, `!.env.example`, `!dev.json.example`, build outputs, `.supabase/`.

---

## 5. Database migrations, in order

All DDL in `supabase/migrations/`, verified locally by `supabase db reset` + pgTAP, then `supabase db push` to the linked project.

**M1 — 20260718000001_identity_and_roles.sql**
- Enums: `user_role` (`super_admin|school_admin|teacher`), `session_status` (`uploaded|validated|invalid`), `media_type` (`image|icon|audio|animation`).
- `profiles` (id uuid PK → auth.users on delete cascade, full_name text, created_at).
- `user_roles` (user_id → auth.users, role user_role, school_id uuid null — FK added in M2, unique(user_id)). Single source for every permission check (ADR-011).
- `public.custom_access_token_hook(event jsonb) returns jsonb` — stamps `user_role`, `school_id` claims from `user_roles`; grant to `supabase_auth_admin`; enabled in `config.toml` (`[auth.hook.custom_access_token]`).
- Helper functions for RLS: `auth_role()`, `auth_school_id()` (read JWT claims, `stable`).

**M2 — 20260718000002_tenancy.sql**
- `schools` (id, name, created_at) · `classes` (id, school_id FK, name, grade smallint) · `students` (id, school_id FK, class_id FK, full_name, roll_number text, birth_year smallint null, is_active bool default true) · `teacher_classes` (teacher_id → auth.users, class_id FK, unique pair). Add deferred FK `user_roles.school_id → schools`.

**M3 — 20260718000003_content.sql**
- `assessment_modules` (module_key text PK, name, enabled bool).
- `media_assets` (id, type media_type, storage_path text, uploaded_by uuid null, metadata jsonb, created_at).
- `categories` (id, key text unique, name, enabled) · `category_items` (id, category_id FK, label, media_asset_id FK).
- `levels` (id, module_key FK, name, difficulty_rank int, enabled) · `level_versions` (id, level_id FK, version int, config jsonb, created_at, unique(level_id, version)). Trigger forbids UPDATE on `level_versions` (append-only, ADR-009).

**M4 — 20260718000004_sessions.sql**
- `sessions` (id uuid PK client-generated, student_id/teacher_id/class_id/school_id FKs, module_key FK, level_version_id FK, device_meta jsonb, event_schema_version int, status session_status default 'uploaded', started_at timestamptz, completed_at, was_interrupted bool default false, provisional_metrics jsonb, created_at).
- `session_events` PARTITION BY RANGE (recorded_at): (session_id FK, seq int, event_type text, t_ms int, payload jsonb, recorded_at timestamptz default now(); PK (session_id, seq, recorded_at)). Function `ensure_session_event_partitions(months_ahead int)` creates monthly partitions; called in-migration for current+3 months; `pg_cron` monthly job scheduled (pg_cron pre-enabled on Supabase; if unavailable locally, migration guards with `IF EXISTS`).
- `session_metrics` (session_id FK, metrics_version int, computed_at, total_time_ms int, accuracy numeric, error_count int, extra jsonb, PK(session_id, metrics_version)).
- REVOKE UPDATE, DELETE ON `session_events` FROM authenticated, anon (immutability by grant).

**M5 — 20260718000005_platform_ops.sql**
- `app_versions` (id, version text, minimum_supported_version text, release_notes text, released_at timestamptz).
- `feature_flags` (key text PK, enabled bool, description text).
- `teacher_notes` (id, session_id FK null, student_id FK, teacher_id, body text, created_at).
- `audit_logs` (id bigint identity, actor_id uuid, action text, entity text, entity_id text, before jsonb, after jsonb, at timestamptz default now()); insert-only grants.

**M6 — 20260718000006_rls_policies.sql**
- `ALTER TABLE … ENABLE ROW LEVEL SECURITY` on every table.
- Read scope: super_admin → all; school_admin → rows where school matches claim; teacher → their school (roster/content read; write only on `sessions`/`session_events` insert for their own teacher_id, `teacher_notes` own rows).
- Roster/content writes: school_admin (own school) + super_admin. `app_versions`/`feature_flags`: read by all authenticated; write super_admin only. `audit_logs`: insert authenticated, select admins.
- Audit trigger `log_admin_mutation()` attached to roster + content + platform-ops tables.

## 6. Seed data (supabase/seed.sql)

- 1 demo school ("MindSprint Demo School"), 2 classes (Grade 4A, Grade 5B), 10 students (5 per class, generic names, birth_year set).
- Modules: `memory_recall`, `math_speed` (math disabled via feature flag).
- 3 categories (animals, fruits, shapes) × 6 items each; `media_assets` rows pointing to placeholder storage paths (`seed/animals/cat.png` …).
- 2 starter levels per module with `level_versions` v1 configs matching `packages/contracts/levels/v1` schemas.
- `app_versions`: (0.1.0, min 0.1.0, "Phase 1 foundation") · `feature_flags`: memory_module=true, maths_module=false, session_replay=false, benchmark_engine=false, adaptive_difficulty=false.
- Test users (created via script `tools/seed-users.md` documenting dashboard/CLI creation — auth users can't be seeded by plain SQL): 1 super_admin, 1 school_admin, 1 teacher (assigned both classes).

---

## 7. File-by-file implementation plan (tasks in execution order)

### Task 1: Repo scaffold + Supabase link
**Files:** Create `.gitignore`, `README.md`, `docs/CHANGELOG.md`, `supabase/config.toml` (via `supabase init`).
**Steps:** `supabase init` → `supabase link --project-ref ddiqmwyavbvmqgbndwpa` (user enters DB password interactively) → `supabase start` locally → verify `supabase status` healthy → commit.
**Test:** `supabase db reset` succeeds on empty migration set.

### Task 2: Migrations M1–M2 (identity, roles, tenancy)
**Files:** Create the two migration files above + `supabase/tests/01_schema.sql` (pgTAP: tables exist, enums exist, `custom_access_token_hook` exists and returns claims for a fixture user).
**Steps:** write M1 → `supabase db reset` → write pgTAP asserts → `supabase test db` PASS → write M2 → reset + test → commit each migration separately.

### Task 3: Migrations M3–M5 (content, sessions, platform ops)
**Files:** three migration files + extend `01_schema.sql` (partitions exist for current+3 months; `level_versions` UPDATE rejected; `session_events` UPDATE/DELETE revoked → covered in 03_immutability.sql).
**Test:** `supabase test db` PASS; manual: insert a session_event, attempt UPDATE as authenticated role → permission denied.

### Task 4: Migration M6 (RLS) + pgTAP RLS suite
**Files:** M6 + `supabase/tests/02_rls.sql` (impersonation tests: teacher of school A cannot read school B students; teacher cannot UPDATE students; school_admin scoped writes; anon sees nothing) + `03_immutability.sql`.
**Test:** `supabase test db` PASS — this suite is the security gate for the whole platform.

### Task 5: Seed + contracts package
**Files:** `supabase/seed.sql`, `tools/seed-users.md`, `packages/contracts/**` (schemas for the 10 v1 event types from spec §8, 2 level-config schemas, definitions.md, 1 trivial fixture), `tools/validate-contracts.mjs`.
**Test:** `supabase db reset` (applies seed) → row counts asserted in pgTAP; `node tools/validate-contracts.mjs` exits 0.

### Task 6: Flutter project creation + core
**Files:** `flutter create --org com.mindsprint --project-name mindsprint_student` (then set `applicationId com.mindsprint.app`); `lib/core/theme/app_theme.dart` (Material 3, child-friendly tokens, 48dp+ touch targets), `lib/core/router/app_router.dart` (routes: /login, /roster, /confirm, /session-stub, /result-stub; session routes flagged for kiosk guard), `lib/core/di/providers.dart`, `lib/core/errors/failures.dart`, `analysis_options.yaml` (strict).
**Test:** `flutter analyze` clean; `flutter test` default widget test replaced by router smoke test (app boots to /login).

### Task 7: TimingService + event recorder + Drift store
**Files:** `lib/core/timing/timing_service.dart` (interface: `start()`, `int get nowMs` monotonic, `DateTime get sessionStartWallClock`), `lib/features/assessments/engine/session_recorder.dart` (`record(String eventType, Map payload)` → assigns seq + t_ms, batches to Drift every 500 ms and on flush()), `lib/data/local/app_database.dart` (Drift tables: `local_events`, `pending_uploads`), generated code via build_runner.
**Tests (unit, mocktail + fake clock):** monotonicity under wall-clock changes; seq strictly increasing; batch flush on interval and on lifecycle flush; events persisted and readable back in order; pending_uploads enqueue/dequeue. This is the most-tested code in Phase 1.

### Task 8: Auth feature (login + PIN + version/flag gate)
**Files:** `lib/data/remote/supabase_client.dart`; `lib/features/auth/{domain/auth_repository.dart, data/auth_repository_impl.dart, presentation/login_screen.dart, presentation/auth_controller.dart, presentation/pin_setup_dialog.dart}`; startup gate `lib/features/auth/domain/startup_gate.dart` — after login: fetch latest `app_versions` row → block with update prompt if below `minimum_supported_version`; fetch `feature_flags` into a provider.
**Tests:** controller unit tests with mocked repository (success, wrong password, offline error message); startup gate blocks when below min version; widget test: login form validation + large touch targets.

### Task 9: Roster feature + teacher-confirm dialog
**Files:** `lib/features/roster/{domain/roster_repository.dart, data/roster_repository_impl.dart, presentation/class_list_screen.dart, presentation/student_list_screen.dart, presentation/confirm_student_dialog.dart}`.
Behavior: teacher sees only their assigned classes (RLS does the filtering — client just queries); selecting a student opens the confirmation dialog (student name, class, Start/Cancel); Start navigates to session-stub screen (kiosk-locked: back trapped, exit via PIN prompt).
**Tests:** repository unit tests (mocked PostgREST responses); widget tests: confirm dialog shows correct name, cancel returns, back-button trap on stub screen.

### Task 10: Next.js scaffold + auth
**Files:** `create-next-app` (TS, Tailwind, App Router) → shadcn init + components; `lib/supabase/{server.ts, client.ts, middleware.ts}` (@supabase/ssr pattern); `app/(auth)/login/page.tsx`; `middleware.ts` (redirect unauthenticated → /login); `app/(dashboard)/layout.tsx` (sidebar shell: Overview, Schools, Classes, Teachers, Students, Content, Settings — Content/Settings as stubs).
**Tests:** vitest: middleware redirect logic; `tsc --noEmit` clean; `npm run lint` clean.

### Task 11: Admin queries layer + roster CRUD
**Files:** `lib/queries/{schools.ts, classes.ts, students.ts, teachers.ts}` (all data access here — pages never query inline); `app/(dashboard)/schools/page.tsx` + create/edit dialogs; same pattern for classes, students (form fields limited to allowed PII: name, roll, birth year), teachers (list + class assignment; teacher *invitation* documented as manual dashboard step in P1); `types/database.ts` via `supabase gen types typescript --linked`.
**Tests:** vitest unit tests on query functions with mocked supabase client (correct filters/payloads); zod schemas reject bad input (e.g., birth_year 1800).

### Task 12: CI + verification + completion report
**Files:** `.github/workflows/ci.yml` — jobs: (a) flutter: analyze + test; (b) admin: lint + tsc + vitest; (c) contracts: validate-contracts.mjs; (d) db: supabase start + `supabase test db` (pgTAP) on Linux runner. `docs/CHANGELOG.md` entry; Phase 1 completion report appended to this plan's PR/commit description.
**Test:** CI green on the repo's main branch.

---

## 8. Testing strategy

| Layer | Tool | What is proven in Phase 1 |
|---|---|---|
| Database schema | pgTAP via `supabase test db` | tables/enums/partitions exist; hook emits claims; level_versions append-only; session_events immutable |
| RLS (security gate) | pgTAP impersonation | cross-school isolation; role write limits; anon blocked |
| Flutter unit | flutter_test + mocktail | TimingService monotonicity; recorder seq/batching; Drift persistence; auth controller; startup gate; roster repo |
| Flutter widget | flutter_test | login validation, confirm dialog, kiosk back-trap, router smoke |
| Admin unit | vitest + RTL | queries layer, zod validation, middleware redirects |
| Contracts | ajv script | fixtures validate against event/level schemas |
| Manual checklist | human | login on Android emulator + Windows; roster browse; confirm dialog; admin CRUD round-trip visible in both apps |

Integration tests across app↔Supabase are deferred to Phase 2 (when there is gameplay to integrate); Phase 1's DB-side behavior is covered by pgTAP against a real local Postgres.

## 9. Estimated implementation order & effort

Tasks run 1→12 sequentially (each is independently reviewable/rejectable). Rough effort: T1 ~0.5 session · T2–T4 ~2 (RLS suite is the slow, important part) · T5 ~1 · T6 ~0.5 · T7 ~1.5 · T8–T9 ~2 · T10–T11 ~2 · T12 ~1. Total ≈ 10–11 working sessions.

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Local env missing Flutter SDK / Android SDK / Supabase CLI / Docker (needed for `supabase start`) | T1 begins with an environment audit; install steps documented in README; APK build proven on Android emulator before phase close |
| pg_cron unavailable in local dev container | Partition creation runs in-migration for +3 months; cron job creation guarded; production job verified on linked project |
| Dependency versions moved since plan date | Pin at install; `flutter pub outdated` / `npm outdated` reviewed; lockfiles committed; completion report records exact versions |
| RLS policy gaps (the security boundary) | pgTAP impersonation suite written BEFORE policies are trusted; any later policy change must extend the suite first |
| Auth users not seedable via SQL | Documented manual creation + `user_roles` insert script; treated as one-time pilot setup, automated in a later phase if needed |
| supabase_flutter session persistence conflicts with kiosk model | Teacher session persists (by design — teacher logs in once per day); kiosk lock + PIN is the in-classroom boundary, tested by widget tests |
| Scope creep into gameplay | Session/result screens are explicit stubs; any gameplay code in review = task rejected |

## 11. Verification checklist (phase gate)

- [ ] `supabase db reset` clean: 6 migrations + seed apply with zero errors
- [ ] `supabase test db`: all pgTAP suites pass (schema, RLS, immutability)
- [ ] Manual SQL: UPDATE on `session_events` as authenticated → rejected
- [ ] JWT for seeded teacher contains `user_role` + `school_id` claims
- [ ] `flutter analyze` zero warnings; `flutter test` all green
- [ ] APK builds (`flutter build apk --debug`) and runs on Android emulator; Windows build runs
- [ ] Teacher can: log in → set PIN → see only assigned classes → open student list → confirm dialog → reach kiosk-locked stub → exit only via PIN
- [ ] Version gate: setting `minimum_supported_version` above app version blocks login with update prompt
- [ ] Admin: log in → CRUD a school/class/student → change visible in Flutter roster after refresh
- [ ] `audit_logs` rows written for admin mutations
- [ ] `npm run lint`, `tsc --noEmit`, `vitest` all green; contracts validator green
- [ ] CI workflow green end-to-end
- [ ] No secrets in git history (`git log -p | grep` audit for service key / password)
- [ ] Completion report written: shipped / stubbed / debt / recommendations / readiness score
