-- Immutability guarantees: raw events and metrics cannot be modified by
-- clients, and level_versions is append-only even for privileged roles.
begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

-- Fixtures --------------------------------------------------------------------

insert into public.schools (id, name)
values ('11111111-1111-1111-1111-111111111111', 'School A');
insert into public.classes (id, school_id, name)
values ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Class A');
insert into public.students (id, school_id, class_id, full_name)
values ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333', 'Student A');
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
insert into public.sessions
  (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
values ('99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'memory_recall',
        '88888888-8888-8888-8888-888888888888', now());
insert into public.session_events (session_id, seq, event_type, t_ms, payload)
values ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}');
insert into public.session_metrics (session_id, metrics_version, total_time_ms)
values ('99999999-9999-9999-9999-999999999999', 1, 60000);

-- level_versions is append-only even for the table owner ----------------------

select throws_ok(
  $$update public.level_versions set config = '{"tampered": true}'
    where id = '88888888-8888-8888-8888-888888888888'$$,
  'P0001', 'level_versions is append-only; insert a new version instead of updating',
  'level_versions rejects UPDATE via trigger');

-- Clients cannot modify the event log or metrics ------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'role', 'authenticated',
  'user_role', 'teacher',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select throws_ok(
  $$update public.session_events set t_ms = 1
    where session_id = '99999999-9999-9999-9999-999999999999'$$,
  '42501', null, 'authenticated cannot UPDATE session_events (grant revoked)');

select throws_ok(
  $$delete from public.session_events
    where session_id = '99999999-9999-9999-9999-999999999999'$$,
  '42501', null, 'authenticated cannot DELETE session_events (grant revoked)');

select throws_ok(
  $$update public.session_metrics set total_time_ms = 1
    where session_id = '99999999-9999-9999-9999-999999999999'$$,
  '42501', null, 'authenticated cannot UPDATE session_metrics (grant revoked)');

reset role;
select * from finish();
rollback;
