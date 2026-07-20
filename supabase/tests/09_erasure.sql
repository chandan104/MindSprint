-- delete_student: full cascade, audit-before-erase, and authorization.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

-- Fixtures --------------------------------------------------------------------

insert into public.schools (id, name) values
  ('11111111-1111-1111-1111-111111111111', 'School A'),
  ('22222222-2222-2222-2222-222222222222', 'School B');
insert into public.classes (id, school_id, name)
values ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Class A');
insert into public.students (id, school_id, class_id, full_name)
values ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333', 'Student A');
insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher-a@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin-a@test.local'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'admin-b@test.local');
insert into public.user_roles (user_id, role, school_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher', '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'school_admin', '11111111-1111-1111-1111-111111111111'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'school_admin', '22222222-2222-2222-2222-222222222222');
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
values ('99999999-9999-9999-9999-999999999999', 1, 1000);
insert into public.teacher_notes (student_id, teacher_id, body)
values ('55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'A note');

-- Teacher may NOT erase ------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'role', 'authenticated',
  'user_role', 'teacher',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select throws_ok(
  $$select public.delete_student('55555555-5555-5555-5555-555555555555', 'test')$$,
  '42501', null, 'a teacher cannot erase student data');

-- Cross-school admin may NOT erase -------------------------------------------

select set_config('request.jwt.claims', json_build_object(
  'sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'role', 'authenticated',
  'user_role', 'school_admin',
  'school_id', '22222222-2222-2222-2222-222222222222'
)::text, true);

select throws_ok(
  $$select public.delete_student('55555555-5555-5555-5555-555555555555', 'test')$$,
  '42501', null, 'a school admin of another school cannot erase');

-- Reason is mandatory --------------------------------------------------------

select set_config('request.jwt.claims', json_build_object(
  'sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'role', 'authenticated',
  'user_role', 'school_admin',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select throws_ok(
  $$select public.delete_student('55555555-5555-5555-5555-555555555555', '  ')$$,
  null, null, 'a blank reason is rejected');

-- The authorized erase -------------------------------------------------------

select lives_ok(
  $$select public.delete_student('55555555-5555-5555-5555-555555555555',
                                 'Parent requested erasure')$$,
  'the school admin erases with a reason');

reset role;

select results_eq(
  $$select count(*)::int from public.students
     where id = '55555555-5555-5555-5555-555555555555'$$,
  array[0], 'student row is gone');

select results_eq(
  $$select count(*)::int from public.session_events
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[0], 'session events are gone');

select results_eq(
  $$select count(*)::int from public.teacher_notes$$,
  array[0], 'teacher notes are gone');

select results_eq(
  $$select (before ->> 'reason') from public.audit_logs
     where action = 'ERASE' and entity_id = '55555555-5555-5555-5555-555555555555'$$,
  array['Parent requested erasure'::text],
  'the audit ledger records who, what, and why');

select * from finish();
rollback;
