-- M4: Event-sourcing core — sessions, immutable partitioned event log,
-- canonical metric projections.

create table public.sessions (
  -- Client-generated UUID: retried uploads are idempotent.
  id uuid primary key,
  student_id uuid not null references public.students (id) on delete cascade,
  teacher_id uuid not null references auth.users (id),
  class_id uuid not null references public.classes (id),
  school_id uuid not null references public.schools (id),
  module_key text not null references public.assessment_modules (module_key),
  level_version_id uuid not null references public.level_versions (id),
  device_meta jsonb not null default '{}'::jsonb,
  event_schema_version integer not null default 1,
  status public.session_status not null default 'uploaded',
  started_at timestamptz not null,
  completed_at timestamptz,
  was_interrupted boolean not null default false,
  provisional_metrics jsonb,
  created_at timestamptz not null default now()
);

create index sessions_student_id_idx on public.sessions (student_id);
create index sessions_school_id_idx on public.sessions (school_id);
create index sessions_status_idx on public.sessions (status) where status = 'uploaded';

-- The immutable event log. Range-partitioned by month from day one: this table
-- dominates row count at scale and retrofitting partitioning is misery.
create table public.session_events (
  session_id uuid not null references public.sessions (id) on delete cascade,
  seq integer not null,
  event_type text not null,
  t_ms integer not null,
  payload jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now(),
  primary key (session_id, seq, recorded_at)
) partition by range (recorded_at);

create or replace function public.ensure_session_event_partitions(months_ahead integer default 3)
returns void
language plpgsql
as $fn$
declare
  d date := date_trunc('month', now())::date;
  part_name text;
  i integer;
begin
  for i in 0..months_ahead loop
    part_name := 'session_events_' || to_char(d, 'YYYY_MM');
    execute format(
      'create table if not exists public.%I partition of public.session_events for values from (%L) to (%L)',
      part_name, d, (d + interval '1 month')::date
    );
    d := (d + interval '1 month')::date;
  end loop;
end;
$fn$;

select public.ensure_session_event_partitions(3);

-- Monthly partition top-up where pg_cron is available (hosted project); local
-- dev containers without pg_cron simply skip the schedule.
do $do$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
  end if;
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'ensure-session-event-partitions',
      '0 0 1 * *',
      'select public.ensure_session_event_partitions(3)'
    );
  end if;
end;
$do$;

-- Canonical metrics: projections of the event log, recomputable by bumping
-- metrics_version. Written only by the compute function (arrives Phase 4).
create table public.session_metrics (
  session_id uuid not null references public.sessions (id) on delete cascade,
  metrics_version integer not null,
  computed_at timestamptz not null default now(),
  total_time_ms integer,
  accuracy numeric,
  error_count integer,
  extra jsonb not null default '{}'::jsonb,
  primary key (session_id, metrics_version)
);

-- Immutability by grant, not convention.
revoke update, delete on public.session_events from authenticated, anon;
revoke update, delete on public.session_metrics from authenticated, anon;
