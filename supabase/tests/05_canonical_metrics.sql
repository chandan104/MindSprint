-- Canonical metrics drift guard: the EXACT numbers from
-- packages/contracts/fixtures/memory_recall_basic.json (expected_metrics_v1).
-- The Dart provisional engine asserts these same values in
-- apps/student/test/features/results/provisional_metrics_test.dart.
-- If either engine drifts from the contract, a build fails.
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

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

-- The 11 fixture events, verbatim t_ms values.
insert into public.session_events (session_id, seq, event_type, t_ms, payload) values
  ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}'),
  ('99999999-9999-9999-9999-999999999999', 2, 'sequence_display_started', 520,
   '{"sequence": [{"item_id": "cat", "label": "Cat"}, {"item_id": "dog", "label": "Dog"}, {"item_id": "lion", "label": "Lion"}]}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'item_displayed', 520,
   '{"item_id": "cat", "label": "Cat", "position_index": 0}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'item_displayed', 2420,
   '{"item_id": "dog", "label": "Dog", "position_index": 1}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'item_displayed', 4320,
   '{"item_id": "lion", "label": "Lion", "position_index": 2}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'sequence_hidden', 5820, '{}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'tap_registered', 7013,
   '{"target_kind": "choice", "item_id": "cat", "label": "Cat", "is_correct": true, "x": 120.5, "y": 340.0}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'tap_registered', 8455,
   '{"target_kind": "choice", "item_id": "tiger", "label": "Tiger", "is_correct": false, "x": 260.0, "y": 341.5}'),
  ('99999999-9999-9999-9999-999999999999', 9, 'tap_registered', 9310,
   '{"target_kind": "choice", "item_id": "dog", "label": "Dog", "is_correct": true, "x": 190.0, "y": 342.0}'),
  ('99999999-9999-9999-9999-999999999999', 10, 'tap_registered', 10102,
   '{"target_kind": "choice", "item_id": "lion", "label": "Lion", "is_correct": true, "x": 320.5, "y": 339.0}'),
  ('99999999-9999-9999-9999-999999999999', 11, 'session_completed', 10650, '{}');

-- Compute ---------------------------------------------------------------------

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the fixture session');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[10650], 'total_time_ms matches the fixture');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[0.75::numeric], 'accuracy matches the fixture');

select results_eq(
  $$select error_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[1], 'error_count matches the fixture');

select results_eq(
  $$select (extra ->> 'reaction_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[6493], 'reaction_time_ms matches the fixture');

select results_eq(
  $$select (extra ->> 'recall_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[1193], 'recall_time_ms matches the fixture');

select results_eq(
  $$select (extra ->> 'hesitation_count')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[0], 'hesitation_count matches the fixture');

select results_eq(
  $$select (extra ->> 'longest_pause_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[1442], 'longest_pause_ms matches the fixture');

select results_eq(
  $$select (extra ->> 'median_decision_ms')::numeric from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[855::numeric], 'median_decision_ms matches the fixture');

select results_eq(
  $$select (extra ->> 'fastest_decision_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[792], 'fastest_decision_ms matches the fixture');

select results_eq(
  $$select (extra ->> 'slowest_decision_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999' and metrics_version = 1$$,
  array[1442], 'slowest_decision_ms matches the fixture');

select results_eq(
  $$select status::text from public.sessions
     where id = '99999999-9999-9999-9999-999999999999'$$,
  array['validated'], 'session transitions to validated');

-- Recompute is idempotent (upsert, still exactly one metrics row).
select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'recompute succeeds');

select results_eq(
  $$select count(*)::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1], 'recompute upserts rather than duplicating');

select * from finish();
rollback;
