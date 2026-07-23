-- RLS impersonation suite: the security gate for the whole platform.
-- Simulates teachers / school admins / anon by setting role + JWT claims,
-- and proves cross-school isolation and write limits.
begin;
create extension if not exists pgtap with schema extensions;

select plan(17);

-- Fixtures (as table owner, bypasses RLS) ------------------------------------

insert into public.schools (id, name) values
  ('11111111-1111-1111-1111-111111111111', 'School A'),
  ('22222222-2222-2222-2222-222222222222', 'School B');

insert into public.classes (id, school_id, name, grade) values
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Class 4A', 4),
  ('44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'Class 5B', 5);

insert into public.students (id, school_id, class_id, full_name) values
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333333', 'Student A'),
  ('66666666-6666-6666-6666-666666666666', '22222222-2222-2222-2222-222222222222',
   '44444444-4444-4444-4444-444444444444', 'Student B');

insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher-a@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin-a@test.local');

insert into public.user_roles (user_id, role, school_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher', '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'school_admin', '11111111-1111-1111-1111-111111111111');

-- Seed data may already provide these; fixtures must not collide with it.
insert into public.assessment_modules (module_key, name)
values ('memory_recall', 'Memory Recall')
on conflict (module_key) do nothing;
insert into public.levels (id, module_key, name) values
  ('77777777-7777-7777-7777-777777777777', 'memory_recall', 'Level 1');
insert into public.level_versions (id, level_id, version, config) values
  ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 1, '{}');

insert into public.feature_flags (key, enabled, description)
values ('rls_test_flag', true, 'test flag');

-- Teacher of School A --------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'role', 'authenticated',
  'user_role', 'teacher',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select results_eq(
  'select count(*)::int from public.schools',
  array[1], 'teacher sees only their own school');

select results_eq(
  'select count(*)::int from public.students',
  array[1], 'teacher sees only own-school students');

select throws_ok(
  $$insert into public.students (school_id, class_id, full_name)
    values ('11111111-1111-1111-1111-111111111111',
            '33333333-3333-3333-3333-333333333333', 'Intruder')$$,
  '42501', null, 'teacher cannot insert students');

-- RLS silently filters UPDATE to zero rows for teachers; prove the row survived.
update public.students set full_name = 'Hacked'
 where id = '55555555-5555-5555-5555-555555555555';
select results_eq(
  $$select full_name from public.students
     where id = '55555555-5555-5555-5555-555555555555'$$,
  array['Student A'::text], 'teacher cannot update students (0 rows affected)');

select lives_ok(
  $$insert into public.sessions
      (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
    values ('99999999-9999-9999-9999-999999999999',
            '55555555-5555-5555-5555-555555555555',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            '33333333-3333-3333-3333-333333333333',
            '11111111-1111-1111-1111-111111111111',
            'memory_recall',
            '88888888-8888-8888-8888-888888888888',
            now())$$,
  'teacher can insert their own session');

select throws_ok(
  $$insert into public.sessions
      (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
    values (gen_random_uuid(),
            '66666666-6666-6666-6666-666666666666',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            '44444444-4444-4444-4444-444444444444',
            '22222222-2222-2222-2222-222222222222',
            'memory_recall',
            '88888888-8888-8888-8888-888888888888',
            now())$$,
  '42501', null, 'teacher cannot insert a session for another school');

select lives_ok(
  $$insert into public.session_events (session_id, seq, event_type, t_ms, payload)
    values ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}')$$,
  'owning teacher can insert session events');

select results_eq(
  $$select count(*)::int from public.feature_flags where key = 'rls_test_flag'$$,
  array[1], 'teacher can read feature flags');

select results_eq(
  'select count(*)::int from public.audit_logs',
  array[0], 'teacher cannot read audit logs');

-- School admin of School A ---------------------------------------------------

select set_config('request.jwt.claims', json_build_object(
  'sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'role', 'authenticated',
  'user_role', 'school_admin',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select lives_ok(
  $$insert into public.students (school_id, class_id, full_name)
    values ('11111111-1111-1111-1111-111111111111',
            '33333333-3333-3333-3333-333333333333', 'New Student A')$$,
  'school admin can insert students in own school');

select throws_ok(
  $$insert into public.students (school_id, class_id, full_name)
    values ('22222222-2222-2222-2222-222222222222',
            '44444444-4444-4444-4444-444444444444', 'Cross Tenant')$$,
  '42501', null, 'school admin cannot insert students in another school');

select throws_ok(
  $$insert into public.session_events (session_id, seq, event_type, t_ms, payload)
    values ('99999999-9999-9999-9999-999999999999', 2, 'tap_registered', 100, '{}')$$,
  '42501', null, 'non-owning user cannot insert events into another teacher''s session');

select is(
  (select count(*) from public.audit_logs),
  0::bigint,
  'school admin cannot read audit logs (cross-tenant; super_admin only)');

select results_eq(
  'select count(*)::int from public.user_roles',
  array[2], 'school admin sees own-school user_roles (teacher + self)');

select results_eq(
  $$select count(*)::int from public.user_roles
     where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  array[1], 'school admin can see the teacher''s role row for the teachers page');

-- Anonymous ------------------------------------------------------------------

set local role anon;
select set_config('request.jwt.claims', '', true);

select throws_ok(
  'select count(*) from public.schools',
  '42501', null, 'anon has no grant on schools at all');

select throws_ok(
  'select count(*) from public.students',
  '42501', null, 'anon has no grant on students at all');

reset role;
select * from finish();
rollback;
