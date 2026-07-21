-- Canonical-engine drift guard for the visual_search fixture
-- (packages/contracts/fixtures/visual_search_basic.json).
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

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
values ('visual_search', 'Visual Search')
on conflict (module_key) do nothing;
insert into public.levels (id, module_key, name)
values ('77777777-7777-7777-7777-777777777777', 'visual_search', 'Level 1');
insert into public.level_versions (id, level_id, version, config)
values ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 1, '{}');
insert into public.sessions
  (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
values ('99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'visual_search',
        '88888888-8888-8888-8888-888888888888', now());

insert into public.session_events (session_id, seq, event_type, t_ms, payload) values
  ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}'),
  ('99999999-9999-9999-9999-999999999999', 2, 'question_displayed', 300,
   '{"question_text": "Find the Cat!", "expected_answer": "Cat", "options": [{"item_id":"cat","label":"Cat"},{"item_id":"not_present","label":"Not here!"}]}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'tap_registered', 850,
   '{"target_kind": "choice", "item_id": "cat", "label": "Cat", "is_correct": true, "x": 140.0, "y": 300.0}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'question_displayed', 1350,
   '{"question_text": "Find the Cat!", "expected_answer": "not_present", "options": [{"item_id":"dog","label":"Dog"},{"item_id":"not_present","label":"Not here!"}]}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'tap_registered', 7500,
   '{"target_kind": "choice", "item_id": "not_present", "label": "Not here!", "is_correct": true, "x": 400.0, "y": 900.0}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'question_displayed', 8000,
   '{"question_text": "Find the Star!", "expected_answer": "Star", "options": [{"item_id":"star","label":"Star"},{"item_id":"not_present","label":"Not here!"}]}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'answer_submitted', 23000,
   '{"answer": "timeout", "is_correct": false}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'session_completed', 23200, '{}');

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the visual_search fixture');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[23200], 'total_time_ms matches');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[0.6667::numeric], 'accuracy = 2 of 3 (correct find + correct not-here, then timeout)');

select results_eq(
  $$select error_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1], 'errors = 1 timeout');

select results_eq(
  $$select (extra ->> 'reaction_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[550], 'reaction_time_ms matches');

select results_eq(
  $$select (extra ->> 'hesitation_count')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1], 'the 6650ms gap before the not-here tap is a hesitation');

select results_eq(
  $$select (extra ->> 'total_idle_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[6650], 'idle time equals the hesitation gap');

select ok(
  (select extra ->> 'recall_time_ms' is null from public.session_metrics
    where session_id = '99999999-9999-9999-9999-999999999999'),
  'recall is null (no sequence_hidden event in this module)');

select * from finish();
rollback;
