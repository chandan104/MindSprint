-- Teacher invite issuance, claim, and denial paths.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

insert into public.schools (id, name) values
  ('11111111-1111-1111-1111-111111111111', 'School A');
insert into auth.users (id, email) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin-a@test.local'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'newteacher@test.local'),
  ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'wrongperson@test.local');
insert into public.user_roles (user_id, role, school_id)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'school_admin', '11111111-1111-1111-1111-111111111111');

-- Admin issues an invite ------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'role', 'authenticated',
  'user_role', 'school_admin',
  'school_id', '11111111-1111-1111-1111-111111111111'
)::text, true);

select lives_ok(
  $$insert into public.teacher_invites (school_id, email, invited_by)
    values ('11111111-1111-1111-1111-111111111111', 'newteacher@test.local',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')$$,
  'school admin issues an invite');

select throws_ok(
  $$insert into public.teacher_invites (school_id, email, invited_by)
    values ('11111111-1111-1111-1111-111111111111', 'newteacher@test.local',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')$$,
  null, null, 'a second pending invite for the same email+school is rejected');

-- Wrong person cannot claim ---------------------------------------------------

select set_config('request.jwt.claims', json_build_object(
  'sub', 'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'role', 'authenticated'
)::text, true);

select throws_ok(
  $$select public.claim_teacher_invite(
      (select token from public.teacher_invites where email = 'newteacher@test.local'))$$,
  null, null, 'claiming with a different account''s email is rejected');

-- Correct person claims -------------------------------------------------------

select set_config('request.jwt.claims', json_build_object(
  'sub', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'role', 'authenticated'
)::text, true);

select lives_ok(
  $$select public.claim_teacher_invite(
      (select token from public.teacher_invites where email = 'newteacher@test.local'))$$,
  'the invited teacher claims the invite');

select results_eq(
  $$select role::text from public.user_roles
     where user_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'$$,
  array['teacher'::text], 'claiming grants the teacher role');

select results_eq(
  $$select school_id from public.user_roles
     where user_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'$$,
  array['11111111-1111-1111-1111-111111111111'::uuid],
  'the role is scoped to the inviting school');

select results_eq(
  $$select status::text from public.teacher_invites
     where email = 'newteacher@test.local'$$,
  array['claimed'::text], 'the invite is marked claimed');

-- Re-claiming a used invite fails ---------------------------------------------

select throws_ok(
  $$select public.claim_teacher_invite(
      (select token from public.teacher_invites where email = 'newteacher@test.local'))$$,
  null, null, 'a claimed invite cannot be claimed again');

reset role;
select * from finish();
rollback;
