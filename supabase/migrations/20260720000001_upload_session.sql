-- upload_session: the single write path for completed/aborted sessions.
--
-- SECURITY INVOKER on purpose: every insert passes through RLS exactly as if
-- the teacher wrote the rows directly — the function adds atomicity and
-- idempotency, never privilege. teacher_id comes from auth.uid(), not the
-- payload: a client cannot attribute a session to someone else.
--
-- Idempotency: client-generated session UUID; retries no-op on the session
-- row and insert only missing events (NOT EXISTS rather than ON CONFLICT
-- because the partitioned PK includes recorded_at, which differs per retry).

create or replace function public.upload_session(
  p_session jsonb,
  p_events jsonb
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_session_id uuid := (p_session ->> 'id')::uuid;
begin
  if v_session_id is null then
    raise exception 'upload_session: session id missing';
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' then
    raise exception 'upload_session: p_events must be a JSON array';
  end if;

  insert into public.sessions
    (id, student_id, teacher_id, class_id, school_id, module_key,
     level_version_id, device_meta, event_schema_version, status,
     started_at, completed_at, was_interrupted, provisional_metrics)
  values
    (v_session_id,
     (p_session ->> 'student_id')::uuid,
     auth.uid(),
     (p_session ->> 'class_id')::uuid,
     (p_session ->> 'school_id')::uuid,
     p_session ->> 'module_key',
     (p_session ->> 'level_version_id')::uuid,
     coalesce(p_session -> 'device_meta', '{}'::jsonb),
     coalesce((p_session ->> 'event_schema_version')::int, 1),
     'uploaded',
     (p_session ->> 'started_at')::timestamptz,
     (p_session ->> 'completed_at')::timestamptz,
     coalesce((p_session ->> 'was_interrupted')::boolean, false),
     p_session -> 'provisional_metrics')
  on conflict (id) do nothing;

  insert into public.session_events (session_id, seq, event_type, t_ms, payload)
  select v_session_id,
         (e ->> 'seq')::int,
         e ->> 'event_type',
         (e ->> 't_ms')::int,
         coalesce(e -> 'payload', '{}'::jsonb)
    from jsonb_array_elements(p_events) e
   where not exists (
     select 1 from public.session_events se
      where se.session_id = v_session_id
        and se.seq = (e ->> 'seq')::int
   );
end;
$$;

grant execute on function public.upload_session(jsonb, jsonb) to authenticated;
revoke execute on function public.upload_session(jsonb, jsonb) from anon, public;
