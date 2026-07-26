-- Canonical-engine drift guard for the color_selector fixture, including the
-- additive instruction_delay_ms metric.
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
values ('color_selector', 'Colour Selector')
on conflict (module_key) do nothing;
insert into public.levels (id, module_key, name)
values ('77777777-7777-7777-7777-777777777777', 'color_selector', 'Level 1');
insert into public.level_versions (id, level_id, version, config)
values ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 1, '{}');
insert into public.sessions
  (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
values ('99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'color_selector',
        '88888888-8888-8888-8888-888888888888', now());

insert into public.session_events (session_id, seq, event_type, t_ms, payload) values
  ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}'),
  ('99999999-9999-9999-9999-999999999999', 2, 'instruction_shown', 300,
   '{"instruction_text": "Tap the RED colour", "instruction_kind": "colour"}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'question_displayed', 1500,
   '{"question_text": "Tap the RED colour", "expected_answer": "red", "options": [{"item_id":"red","label":"Red"},{"item_id":"blue","label":"Blue"}]}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'tap_registered', 2400,
   '{"target_kind": "choice", "item_id": "red", "label": "Red", "is_correct": true, "x": 120.0, "y": 500.0}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'instruction_shown', 3400,
   '{"instruction_text": "Tap the BLUE colour", "instruction_kind": "colour"}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'question_displayed', 4300,
   '{"question_text": "Tap the BLUE colour", "expected_answer": "blue", "options": [{"item_id":"red","label":"Red"},{"item_id":"blue","label":"Blue"}]}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'tap_registered', 9000,
   '{"target_kind": "choice", "item_id": "green", "label": "Green", "is_correct": false, "x": 300.0, "y": 502.0}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'instruction_shown', 10000,
   '{"instruction_text": "Tap the GREEN colour", "instruction_kind": "colour"}'),
  ('99999999-9999-9999-9999-999999999999', 9, 'question_displayed', 10900,
   '{"question_text": "Tap the GREEN colour", "expected_answer": "green", "options": [{"item_id":"red","label":"Red"},{"item_id":"green","label":"Green"}]}'),
  ('99999999-9999-9999-9999-999999999999', 10, 'answer_submitted', 20900,
   '{"answer": "timeout", "is_correct": false}'),
  ('99999999-9999-9999-9999-999999999999', 11, 'session_completed', 21100, '{}');

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the color_selector fixture');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[21100], 'total_time_ms matches');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[0.3333::numeric], 'accuracy = 1 of 3');

select results_eq(
  $$select (extra ->> 'instruction_delay_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1200], 'instruction_delay_ms = first stimulus - first instruction');

select results_eq(
  $$select (extra ->> 'reaction_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[900], 'reaction_time_ms matches');

select results_eq(
  $$select (extra ->> 'hesitation_count')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1], 'the 6600ms gap is a hesitation');

select results_eq(
  $$select (extra ->> 'total_idle_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[6600], 'idle time equals the hesitation gap');

select results_eq(
  $$select error_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[2], 'errors = 1 wrong + 1 timeout');

select * from finish();
rollback;
