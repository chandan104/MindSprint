-- Canonical-engine drift guard for the attention_focus fixture
-- (packages/contracts/fixtures/attention_focus_basic.json). Same numbers the
-- Dart engine asserts. Fixture-first: this suite existed before the gameplay.
begin;
create extension if not exists pgtap with schema extensions;

select plan(9);

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
values ('attention_focus', 'Focus Tap')
on conflict (module_key) do nothing;
insert into public.levels (id, module_key, name)
values ('77777777-7777-7777-7777-777777777777', 'attention_focus', 'Level 1');
insert into public.level_versions (id, level_id, version, config)
values ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 1, '{}');
insert into public.sessions
  (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
values ('99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'attention_focus',
        '88888888-8888-8888-8888-888888888888', now());

insert into public.session_events (session_id, seq, event_type, t_ms, payload) values
  ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}'),
  ('99999999-9999-9999-9999-999999999999', 2, 'item_displayed', 500,
   '{"item_id": "cat", "label": "Cat", "position_index": 0, "is_target": true}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'tap_registered', 1150,
   '{"target_kind": "choice", "item_id": "cat", "label": "Cat", "is_correct": true, "x": 200.0, "y": 400.0}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'item_displayed', 2500,
   '{"item_id": "dog", "label": "Dog", "position_index": 1, "is_target": false}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'answer_submitted', 4000,
   '{"answer": "pass", "is_correct": true}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'item_displayed', 4500,
   '{"item_id": "cat", "label": "Cat", "position_index": 2, "is_target": true}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'tap_registered', 5050,
   '{"target_kind": "choice", "item_id": "cat", "label": "Cat", "is_correct": true, "x": 201.5, "y": 399.0}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'item_displayed', 6500,
   '{"item_id": "lion", "label": "Lion", "position_index": 3, "is_target": false}'),
  ('99999999-9999-9999-9999-999999999999', 9, 'tap_registered', 7010,
   '{"target_kind": "choice", "item_id": "lion", "label": "Lion", "is_correct": false, "x": 198.0, "y": 402.0}'),
  ('99999999-9999-9999-9999-999999999999', 10, 'item_displayed', 8500,
   '{"item_id": "cat", "label": "Cat", "position_index": 4, "is_target": true}'),
  ('99999999-9999-9999-9999-999999999999', 11, 'answer_submitted', 10000,
   '{"answer": "miss", "is_correct": false}'),
  ('99999999-9999-9999-9999-999999999999', 12, 'item_displayed', 10500,
   '{"item_id": "cat", "label": "Cat", "position_index": 5, "is_target": true}'),
  ('99999999-9999-9999-9999-999999999999', 13, 'tap_registered', 11020,
   '{"target_kind": "choice", "item_id": "cat", "label": "Cat", "is_correct": true, "x": 200.5, "y": 401.0}'),
  ('99999999-9999-9999-9999-999999999999', 14, 'session_completed', 12000, '{}');

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the attention fixture');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[12000], 'total_time_ms matches');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[0.6667::numeric], 'accuracy = 4 of 6 responses correct');

select results_eq(
  $$select error_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[2], 'errors = 1 commission + 1 omission');

select results_eq(
  $$select (extra ->> 'hesitation_count')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[2], 'two inter-tap gaps exceed 3000ms');

select results_eq(
  $$select (extra ->> 'total_idle_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[7910], 'idle time = 3900 + 4010');

select results_eq(
  $$select (extra ->> 'median_decision_ms')::numeric from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[3900::numeric], 'median decision gap');

select results_eq(
  $$select (extra ->> 'fastest_decision_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1960], 'fastest decision gap');

select ok(
  (select extra ->> 'reaction_time_ms' is null from public.session_metrics
    where session_id = '99999999-9999-9999-9999-999999999999'),
  'reaction is null in v1 (per-stimulus RT is metrics v2)');

select * from finish();
rollback;
