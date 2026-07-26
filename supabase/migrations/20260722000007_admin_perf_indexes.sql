-- Admin dashboard performance: indexes for the two hottest scan patterns.
-- Additive and safe (indexes only). Idempotent via IF NOT EXISTS.

-- Sessions lists and the dashboard "today" count order/filter by started_at.
-- Without this, every listing does a full scan + sort of the sessions table.
create index if not exists sessions_started_at_desc_idx
  on public.sessions (started_at desc);

-- The cohort comparison scans a school's validated, uninterrupted sessions.
-- A partial index on exactly that predicate keeps it tiny and fast, and orders
-- by started_at so the read is already sorted.
create index if not exists sessions_cohort_idx
  on public.sessions (school_id, started_at desc)
  where status = 'validated' and was_interrupted = false;

-- A student's own report reads their sessions newest-oldest; make that ordered
-- read index-only rather than a per-student sort.
create index if not exists sessions_student_started_idx
  on public.sessions (student_id, started_at);
