-- Teacher notes policies + same-school profile visibility.
begin;
create extension if not exists pgtap with schema extensions;

select plan(6);

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
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'teacher-b@test.local');
insert into public.user_roles (user_id, role, school_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher', '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'school_admin', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'teacher', '22222222-2222-2222-2222-222222222222');
insert into public.profiles (id, full_name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Teacher A'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Admin A'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Teacher B');

-- Teacher A writes a note ------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'role', 'authenticated',
  'user_role', 'teacher',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select lives_ok(
  $$insert into public.teacher_notes (student_id, teacher_id, body)
    values ('55555555-5555-5555-5555-555555555555',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'Confident on sequences today.')$$,
  'teacher can write a note about their school''s student');

-- School admin A reads note + author name -------------------------------------

select set_config('request.jwt.claims', json_build_object(
  'sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'role', 'authenticated',
  'user_role', 'school_admin',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select results_eq(
  $$select count(*)::int from public.teacher_notes
     where student_id = '55555555-5555-5555-5555-555555555555'$$,
  array[1], 'school admin sees the note');

select results_eq(
  $$select full_name from public.profiles
     where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  array['Teacher A'::text],
  'school admin resolves the note author''s name (same school)');

select throws_ok(
  $$insert into public.teacher_notes (student_id, teacher_id, body)
    values ('55555555-5555-5555-5555-555555555555',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Admin note')$$,
  '42501', null, 'school admin cannot author teacher notes');

-- Cross-school teacher B ------------------------------------------------------

select set_config('request.jwt.claims', json_build_object(
  'sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'role', 'authenticated',
  'user_role', 'teacher',
  'school_id', '22222222-2222-2222-2222-222222222222'
)::text, true);

select results_eq(
  $$select count(*)::int from public.profiles
     where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  array[0], 'cross-school teacher cannot read the profile');

select results_eq(
  $$select count(*)::int from public.profiles
     where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'$$,
  array[1], 'teacher reads own profile');

reset role;
select * from finish();
rollback;
