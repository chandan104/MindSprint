-- Canonical-engine drift guard for the pattern_recognition fixture
-- (packages/contracts/fixtures/pattern_recognition_basic.json). Same numbers
-- the Dart engine asserts via its fixture glob.
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
values ('pattern_recognition', 'Pattern Detective')
on conflict (module_key) do nothing;
insert into public.levels (id, module_key, name)
values ('77777777-7777-7777-7777-777777777777', 'pattern_recognition', 'Level 1');
insert into public.level_versions (id, level_id, version, config)
values ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 1, '{}');
insert into public.sessions
  (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
values ('99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'pattern_recognition',
        '88888888-8888-8888-8888-888888888888', now());

insert into public.session_events (session_id, seq, event_type, t_ms, payload) values
  ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}'),
  ('99999999-9999-9999-9999-999999999999', 2, 'question_displayed', 800,
   '{"question_text": "What comes next? (ab pattern)", "expected_answer": "Circle", "sequence": [{"item_id": "circle", "label": "Circle"}, {"item_id": "square", "label": "Square"}, {"item_id": "circle", "label": "Circle"}], "options": [{"item_id": "circle", "label": "Circle"}, {"item_id": "star", "label": "Star"}, {"item_id": "square", "label": "Square"}]}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'tap_registered', 2600,
   '{"target_kind": "choice", "item_id": "circle", "label": "Circle", "is_correct": true, "x": 180.0, "y": 620.0}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'question_displayed', 3800,
   '{"question_text": "What comes next? (abc pattern)", "expected_answer": "Star", "sequence": [{"item_id": "star", "label": "Star"}, {"item_id": "heart", "label": "Heart"}, {"item_id": "moon", "label": "Moon"}], "options": [{"item_id": "heart", "label": "Heart"}, {"item_id": "star", "label": "Star"}, {"item_id": "moon", "label": "Moon"}]}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'tap_registered', 8100,
   '{"target_kind": "choice", "item_id": "moon", "label": "Moon", "is_correct": false, "x": 410.0, "y": 615.0}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'question_displayed', 9300,
   '{"question_text": "What comes next? (ab pattern)", "expected_answer": "Square", "sequence": [{"item_id": "square", "label": "Square"}, {"item_id": "heart", "label": "Heart"}, {"item_id": "square", "label": "Square"}], "options": [{"item_id": "square", "label": "Square"}, {"item_id": "heart", "label": "Heart"}, {"item_id": "circle", "label": "Circle"}]}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'answer_submitted', 24300,
   '{"answer": "timeout", "is_correct": false}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'session_completed', 24500, '{}');

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the pattern fixture');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[24500], 'total_time_ms matches');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[0.3333::numeric], 'accuracy = 1 of 3 (wrong tap + timeout are errors)');

select results_eq(
  $$select error_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[2], 'errors = 1 wrong tap + 1 timeout');

select results_eq(
  $$select (extra ->> 'reaction_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1800], 'reaction = first stimulus to first tap');

select results_eq(
  $$select (extra ->> 'hesitation_count')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1], 'the 5500ms inter-tap gap is a hesitation');

select results_eq(
  $$select (extra ->> 'total_idle_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[5500], 'idle time equals the hesitation gap');

select results_eq(
  $$select (extra ->> 'median_decision_ms')::numeric from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[5500::numeric], 'single decision gap is its own median');

select * from finish();
rollback;
