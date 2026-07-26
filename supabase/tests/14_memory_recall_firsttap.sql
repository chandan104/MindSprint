-- Canonical-engine drift guard for memory_recall_firsttap.json: first-tap-per-
-- slot scoring (a wrong first tap is the scored response, no retry). accuracy =
-- 2 correct / 3 slots. The Dart provisional engine asserts the same numbers.
begin;
create extension if not exists pgtap with schema extensions;

select plan(6);

insert into public.schools (id, name)
values ('11111111-1111-1111-1111-111111111111', 'School A');
insert into public.classes (id, school_id, name)
values ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Class A');
insert into public.students (id, school_id, class_id, full_name)
values ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333', 'Student A');
insert into auth.users (id, email)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher-a@test.local');
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

insert into public.session_events (session_id, seq, event_type, t_ms, payload) values
  ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}'),
  ('99999999-9999-9999-9999-999999999999', 2, 'sequence_display_started', 500,
   '{"sequence": [{"item_id": "cat", "label": "Cat"}, {"item_id": "dog", "label": "Dog"}, {"item_id": "lion", "label": "Lion"}]}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'item_displayed', 500,
   '{"item_id": "cat", "label": "Cat", "position_index": 0}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'item_displayed', 2000,
   '{"item_id": "dog", "label": "Dog", "position_index": 1}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'item_displayed', 3500,
   '{"item_id": "lion", "label": "Lion", "position_index": 2}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'sequence_hidden', 5000, '{}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'tap_registered', 6000,
   '{"target_kind": "choice", "item_id": "cat", "label": "Cat", "is_correct": true, "x": 120.0, "y": 340.0}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'tap_registered', 7000,
   '{"target_kind": "choice", "item_id": "tiger", "label": "Tiger", "is_correct": false, "x": 260.0, "y": 341.0}'),
  ('99999999-9999-9999-9999-999999999999', 9, 'tap_registered', 8500,
   '{"target_kind": "choice", "item_id": "lion", "label": "Lion", "is_correct": true, "x": 320.0, "y": 339.0}'),
  ('99999999-9999-9999-9999-999999999999', 10, 'session_completed', 9000, '{}');

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the first-tap fixture');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[9000], 'total_time_ms matches');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[0.6667::numeric], 'accuracy = 2 correct of 3 slots (no brute-force retry)');

select results_eq(
  $$select correct_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[2], 'correct_count = 2');

select results_eq(
  $$select error_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[1], 'error_count = 1 (the scored wrong first tap)');

select results_eq(
  $$select (extra ->> 'recall_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[1000], 'recall_time_ms = first tap - sequence_hidden');

select * from finish();
rollback;
