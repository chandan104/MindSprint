-- upload_session RPC: happy path, idempotent retry, cross-school rejection.
begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

-- Fixtures --------------------------------------------------------------------

insert into public.schools (id, name) values
  ('11111111-1111-1111-1111-111111111111', 'School A'),
  ('22222222-2222-2222-2222-222222222222', 'School B');
insert into public.classes (id, school_id, name) values
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Class A'),
  ('44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'Class B');
insert into public.students (id, school_id, class_id, full_name) values
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333333', 'Student A'),
  ('66666666-6666-6666-6666-666666666666', '22222222-2222-2222-2222-222222222222',
   '44444444-4444-4444-4444-444444444444', 'Student B');
insert into auth.users (id, email)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher-a@test.local');
insert into public.user_roles (user_id, role, school_id)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher', '11111111-1111-1111-1111-111111111111');
insert into public.assessment_modules (module_key, name)
values ('memory_recall', 'Memory Recall')
on conflict (module_key) do nothing;
insert into public.levels (id, module_key, name)
values ('77777777-7777-7777-7777-777777777777', 'memory_recall', 'Level 1');
insert into public.level_versions (id, level_id, version, config)
values ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 1, '{}');

-- Impersonate teacher A -------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'role', 'authenticated',
  'user_role', 'teacher',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select lives_ok(
  $$select public.upload_session(
      '{"id": "99999999-9999-9999-9999-999999999999",
        "student_id": "55555555-5555-5555-5555-555555555555",
        "class_id": "33333333-3333-3333-3333-333333333333",
        "school_id": "11111111-1111-1111-1111-111111111111",
        "module_key": "memory_recall",
        "level_version_id": "88888888-8888-8888-8888-888888888888",
        "started_at": "2026-07-20T09:00:00Z",
        "completed_at": "2026-07-20T09:01:00Z",
        "provisional_metrics": {"accuracy": 0.75}}'::jsonb,
      '[{"seq": 1, "event_type": "session_started", "t_ms": 0, "payload": {}},
        {"seq": 2, "event_type": "tap_registered", "t_ms": 1500,
         "payload": {"target_kind": "choice", "is_correct": true, "x": 1, "y": 2}},
        {"seq": 3, "event_type": "session_completed", "t_ms": 60000, "payload": {}}]'::jsonb
    )$$,
  'teacher uploads a session with events');

select results_eq(
  $$select count(*)::int from public.sessions
     where id = '99999999-9999-9999-9999-999999999999'$$,
  array[1], 'session row exists');

select results_eq(
  $$select count(*)::int from public.session_events
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[3], 'all three events stored');

-- Retry with an extra event (partial-upload recovery): no duplicates,
-- missing event lands.
select lives_ok(
  $$select public.upload_session(
      '{"id": "99999999-9999-9999-9999-999999999999",
        "student_id": "55555555-5555-5555-5555-555555555555",
        "class_id": "33333333-3333-3333-3333-333333333333",
        "school_id": "11111111-1111-1111-1111-111111111111",
        "module_key": "memory_recall",
        "level_version_id": "88888888-8888-8888-8888-888888888888",
        "started_at": "2026-07-20T09:00:00Z"}'::jsonb,
      '[{"seq": 1, "event_type": "session_started", "t_ms": 0, "payload": {}},
        {"seq": 2, "event_type": "tap_registered", "t_ms": 1500,
         "payload": {"target_kind": "choice", "is_correct": true, "x": 1, "y": 2}},
        {"seq": 3, "event_type": "session_completed", "t_ms": 60000, "payload": {}},
        {"seq": 4, "event_type": "session_completed", "t_ms": 60001, "payload": {}}]'::jsonb
    )$$,
  'retry is accepted');

select results_eq(
  $$select count(*)::int from public.session_events
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[4], 'retry deduplicates existing events and adds only the missing one');

select results_eq(
  $$select teacher_id from public.sessions
     where id = '99999999-9999-9999-9999-999999999999'$$,
  array['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid],
  'teacher_id comes from auth.uid(), not the payload');

-- Cross-school upload is rejected by RLS inside the invoker function.
select throws_ok(
  $$select public.upload_session(
      '{"id": "99999999-9999-9999-9999-000000000001",
        "student_id": "66666666-6666-6666-6666-666666666666",
        "class_id": "44444444-4444-4444-4444-444444444444",
        "school_id": "22222222-2222-2222-2222-222222222222",
        "module_key": "memory_recall",
        "level_version_id": "88888888-8888-8888-8888-888888888888",
        "started_at": "2026-07-20T09:00:00Z"}'::jsonb,
      '[]'::jsonb
    )$$,
  '42501', null, 'cross-school session upload is rejected');

reset role;
select * from finish();
rollback;
