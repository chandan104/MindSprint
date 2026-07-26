-- Canonical-engine drift guard for color_selector_stroop.json: the additive
-- stroop_interference_ms metric (mean incongruent RT − mean congruent RT). The
-- Dart provisional engine asserts the same numbers.
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
  ('99999999-9999-9999-9999-999999999999', 2, 'instruction_shown', 100,
   '{"instruction_text": "Tap the WORD Green", "instruction_kind": "word"}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'question_displayed', 1000,
   '{"question_text": "Tap the WORD Green", "expected_answer": "green", "congruent": true, "options": [{"item_id":"green","label":"Green"},{"item_id":"red","label":"Red"}]}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'tap_registered', 1600,
   '{"target_kind": "choice", "item_id": "green", "label": "Green", "is_correct": true, "x": 120.0, "y": 500.0}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'instruction_shown', 2000,
   '{"instruction_text": "Tap the WORD Red", "instruction_kind": "word"}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'question_displayed', 2500,
   '{"question_text": "Tap the WORD Red", "expected_answer": "red", "congruent": false, "options": [{"item_id":"green","label":"Green"},{"item_id":"red","label":"Red"}]}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'tap_registered', 3400,
   '{"target_kind": "choice", "item_id": "red", "label": "Red", "is_correct": true, "x": 300.0, "y": 500.0}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'instruction_shown', 4000,
   '{"instruction_text": "Tap the WORD Blue", "instruction_kind": "word"}'),
  ('99999999-9999-9999-9999-999999999999', 9, 'question_displayed', 4500,
   '{"question_text": "Tap the WORD Blue", "expected_answer": "blue", "congruent": false, "options": [{"item_id":"blue","label":"Blue"},{"item_id":"red","label":"Red"}]}'),
  ('99999999-9999-9999-9999-999999999999', 10, 'tap_registered', 5600,
   '{"target_kind": "choice", "item_id": "blue", "label": "Blue", "is_correct": true, "x": 120.0, "y": 640.0}'),
  ('99999999-9999-9999-9999-999999999999', 11, 'instruction_shown', 6000,
   '{"instruction_text": "Tap the WORD Yellow", "instruction_kind": "word"}'),
  ('99999999-9999-9999-9999-999999999999', 12, 'question_displayed', 6500,
   '{"question_text": "Tap the WORD Yellow", "expected_answer": "yellow", "congruent": true, "options": [{"item_id":"yellow","label":"Yellow"},{"item_id":"red","label":"Red"}]}'),
  ('99999999-9999-9999-9999-999999999999', 13, 'tap_registered', 7200,
   '{"target_kind": "choice", "item_id": "yellow", "label": "Yellow", "is_correct": true, "x": 300.0, "y": 640.0}'),
  ('99999999-9999-9999-9999-999999999999', 14, 'session_completed', 7500, '{}');

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the Stroop fixture');

select results_eq(
  $$select (extra ->> 'stroop_interference_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[350], 'interference = mean incongruent (1000) - mean congruent (650)');

select results_eq(
  $$select (extra ->> 'instruction_delay_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[900], 'instruction_delay_ms = first question - first instruction');

select results_eq(
  $$select (extra ->> 'reaction_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[600], 'reaction_time_ms = first tap - first stimulus');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1.0000::numeric], 'all four responses correct');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[7500], 'total_time_ms matches');

select * from finish();
rollback;
