-- Schema shape: every table, enum, and function the platform depends on,
-- plus the JWT claims hook behavior and current-month partition.
begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'user_roles', 'user_roles exists');
select has_table('public', 'schools', 'schools exists');
select has_table('public', 'classes', 'classes exists');
select has_table('public', 'students', 'students exists');
select has_table('public', 'teacher_classes', 'teacher_classes exists');
select has_table('public', 'assessment_modules', 'assessment_modules exists');
select has_table('public', 'media_assets', 'media_assets exists');
select has_table('public', 'categories', 'categories exists');
select has_table('public', 'category_items', 'category_items exists');
select has_table('public', 'levels', 'levels exists');
select has_table('public', 'level_versions', 'level_versions exists');
select has_table('public', 'sessions', 'sessions exists');
select has_table('public', 'session_events', 'session_events exists');
select has_table('public', 'session_metrics', 'session_metrics exists');
select has_table('public', 'app_versions', 'app_versions exists');
select has_table('public', 'feature_flags', 'feature_flags exists');
select has_table('public', 'teacher_notes', 'teacher_notes exists');
select has_table('public', 'audit_logs', 'audit_logs exists');

select has_type('public', 'user_role', 'user_role enum exists');
select has_type('public', 'session_status', 'session_status enum exists');
select has_type('public', 'media_type', 'media_type enum exists');

select has_function('public', 'custom_access_token_hook', 'token hook exists');
select has_function('public', 'auth_role', 'auth_role exists');
select has_function('public', 'auth_school_id', 'auth_school_id exists');
select has_function('public', 'ensure_session_event_partitions', 'partition fn exists');
select has_function('public', 'log_admin_mutation', 'audit trigger fn exists');

select has_table(
  'public',
  ('session_events_' || to_char(now(), 'YYYY_MM'))::name,
  'current-month session_events partition exists'
);

-- Token hook stamps claims from user_roles.
insert into public.schools (id, name)
values ('11111111-1111-1111-1111-111111111111', 'Hook Test School');
insert into auth.users (id, email)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'hook-teacher@test.local');
insert into public.user_roles (user_id, role, school_id)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher', '11111111-1111-1111-1111-111111111111');

select is(
  (public.custom_access_token_hook(jsonb_build_object(
    'user_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'claims', '{}'::jsonb
  )) -> 'claims' ->> 'user_role'),
  'teacher',
  'hook stamps user_role claim'
);

select is(
  (public.custom_access_token_hook(jsonb_build_object(
    'user_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'claims', '{}'::jsonb
  )) -> 'claims' ->> 'school_id'),
  '11111111-1111-1111-1111-111111111111',
  'hook stamps school_id claim'
);

select * from finish();
rollback;
