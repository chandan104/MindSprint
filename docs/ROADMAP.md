# Roadmap

Each phase is fully completed, reviewed, tested, and approved before the next begins.
Every phase ends with a completion report: what shipped, what remains, technical debt,
recommendations, readiness score.

## Phase 1 â€” Foundation (no gameplay)

- Monorepo scaffold; docs and ADRs committed
- Supabase: linked project, initial migrations (all core tables, partitioned
  `session_events`, RLS, `user_roles`, access-token hook), seed data
- Flutter skeleton: teacher login, roster browse (school â†’ class â†’ student),
  teacher-confirm dialog, TimingService + event recorder + Drift store proven by tests
- Next.js skeleton: login, dashboard shell, lean roster CRUD
- CI: flutter analyze + tests, tsc + lint + tests, contract fixture runner

## Phase 2 â€” Assessment engine + Memory Recall

- AssessmentModule contract, registry, session recorder wired end-to-end
- Memory Recall module (sequences from seeded categories), kiosk lock
- Events flow: gameplay â†’ Drift â†’ provisional metrics â†’ instant result screen

## Phase 3 â€” Mathematics Speed + sync hardening

- Math Speed module (data-driven question generation rules)
- `upload_session` RPC, retry queue, pending-uploads badge, idempotency verified

## Phase 4 â€” Canonical metrics + first reports

- `compute_session_metrics()` in SQL, pg_cron sweep, drift-guard fixtures in CI
- Admin: session list/detail, student report v1, dashboard overview
  (recently finished Â· needs review)

## Phase 5 â€” Session replay + benchmarks

- Timeline replay reconstructed purely from events (play/pause/scrub)
- Benchmark aggregates (class/school/grade), personal-history comparison
- Teacher notes

## Phase 6 â€” Content tooling + exports

- Media Library admin UI; level/category editing forms (basic Assessment Builder v0)
- CSV/PDF exports; audit-log viewer; data-erasure flow surfaced in admin

## Deferred (architecture-ready, deliberately unbuilt)

| Feature | Trigger to build |
|---|---|
| Adaptive difficulty (on-device engine, server reconciliation) | After pilot data establishes baseline distributions |
| Visual Assessment Builder (full) | When non-developers need to author whole assessments |
| Live Sessions panel (Realtime presence) | When schools ask to monitor in-progress assessments |
| Offline roster/level caching | When pilot schools hit connectivity failures in practice |
| Insights Engine (AI summaries of canonical metrics) | Post-benchmarks, with explicit never-diagnose guardrails |
| Future modules: Pattern Recognition, Visual Search, Attention, Logic, Reaction, Color Recall, Shape Recognition, Sequence Recognition | One module per release cycle as content is designed |
