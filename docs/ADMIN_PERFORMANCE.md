# Admin Dashboard Performance

Goal: the admin panel should feel instantaneous for teachers. This documents the
audit, the baseline, what shipped, and what's deliberately deferred.

## Architecture baseline (already good)

- **Server Components everywhere.** Only 17 client files, most are UI primitives
  or small interactive islands (dialogs, replayer, copy button). Pages fetch on
  the server and stream HTML.
- **All charts are dependency-free server-rendered SVG** (`radar-chart`,
  `trend-line`, `bar-compare`, `sparkline`, `cognitive-snapshot`,
  `cohort-comparison`). Zero client JS, zero re-render cost — so "lazy-load /
  memoize / render-only-visible charts" is already moot; they can't re-render.
- **Reads run as the signed-in user** → RLS scopes every query; no service role.

## Client bundle

Total client chunks ≈ **1.4 MB** (uncompressed). Largest: React framework
(~185 KB), `main` (~129 KB), polyfills (~110 KB), and two vendor chunks (~217 KB
/ ~195 KB) dominated by `@supabase/supabase-js` (auth + browser client used by
the interactive islands). lucide-react is already tree-shaken by Next 16's
default `optimizePackageImports` (verified: adding it explicitly changed nothing
— byte-identical chunk hashes). No dead chart/date libraries are bundled.

## Shipped this pass (Tier 1 — safe, measured)

### 1. De-duplicated auth/role round trips (`React.cache()`)
`auth.getUser()` re-validates the JWT against Supabase Auth on every call — the
slowest kind of round trip. The layout called it directly **and** via
`currentUserRole()` (which called it again), and pages called `currentUserRole()`
a third time. Wrapping `getCurrentUser` and `currentUserRole` in `cache()`
collapses these to once per request.

Supabase round trips per navigation (analytical, from the call graph):

| Page | Before | After | Δ |
|------|-------:|------:|---|
| Dashboard `/` | 9 (getUser ×2, role ×1, counts ×6) | 8 (getUser ×1, role ×1, counts ×6) | −1 |
| Any list page | 3 (getUser ×2, role ×1) + list | 2 (getUser ×1, role ×1) + list | −1 |
| Student profile `/students/[id]` | 10 (getUser ×3, role ×2, report ×3, cohort ×2) | 7 (getUser ×1, role ×1, report ×3, cohort ×2) | **−3** |

Every removed call is an auth-server JWT validation, so the wall-clock saving is
larger than the count suggests.

### 2. Database indexes (migration `…007`)
Two hot scans were unindexed:
- `sessions (started_at desc)` — session lists and the dashboard "today" count
  did a full scan + sort. Now index-ordered.
- Partial `sessions (school_id, started_at desc) where status='validated' and
  was_interrupted=false` — the cohort comparison's exact predicate; keeps the
  index tiny and the read pre-sorted.
- `sessions (student_id, started_at)` — a student's report reads their sessions
  ordered; now index-only instead of a per-student sort.

### 3. `optimizePackageImports` made explicit
No measured change today (Next 16 default already covers lucide-react), but
future barrel imports will be tree-shaken by policy.

## Deferred (Tier 2 — scope against real pilot data)

Sized for a **1-school, <500-student** pilot, these are not yet worth the rewrite
risk; revisit if volumes grow:

- **Students/Sessions tables**: server-side search / sort / pagination and (only
  past ~1–2k rows) virtualization. Today they render all rows; a per-row
  `CrudDialog` also repeats `classOptions` in the RSC payload — refactor to one
  shared dialog.
- **Cohort comparison → SQL**: it currently fetches ≤5000 school sessions and
  recomputes every student's profile in Node on each profile view. Port the
  overall-index aggregation into a Postgres function (or a short-TTL cache keyed
  by the viewer's RLS scope) so it's O(1) reads. Needs care to avoid drifting
  from `lib/insights/cognitive-score.ts` and to stay RLS-correct.
- **Exports**: PDF (browser print route) and XLSX are already generated
  server-side/on-demand and don't block the dashboard; add a progress affordance
  when wired to a button.
- **Runtime reliability sweep** (console/hydration warnings, skeleton loaders,
  layout-shift): needs the preview server against a populated DB — do it during
  pilot bring-up.

## How to measure

- Bundle: `rm -rf .next && npm run build`, then inspect `.next/static/chunks`.
- Query counts: read the call graph (server components + `lib/queries/*`).
- Real load times require the hosted DB with pilot data; capture via the browser
  Network panel once migration `…007` is applied.
