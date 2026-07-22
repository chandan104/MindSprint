-- Canonical-engine drift guard for the sequence_logic fixture
-- (packages/contracts/fixtures/sequence_logic_basic.json).
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
values ('sequence_logic', 'Sequence Logic')
on conflict (module_key) do nothing;
insert into public.levels (id, module_key, name)
values ('77777777-7777-7777-7777-777777777777', 'sequence_logic', 'Level 1');
insert into public.level_versions (id, level_id, version, config)
values ('88888888-8888-8888-8888-888888888888', '77777777-7777-7777-7777-777777777777', 1, '{}');
insert into public.sessions
  (id, student_id, teacher_id, class_id, school_id, module_key, level_version_id, started_at)
values ('99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'sequence_logic',
        '88888888-8888-8888-8888-888888888888', now());

insert into public.session_events (session_id, seq, event_type, t_ms, payload) values
  ('99999999-9999-9999-9999-999999999999', 1, 'session_started', 0, '{}'),
  ('99999999-9999-9999-9999-999999999999', 2, 'question_displayed', 400,
   '{"question_text": "What comes next? (next_in_series)", "expected_answer": "8", "sequence": [{"item_id":"n2","label":"2"},{"item_id":"n4","label":"4"},{"item_id":"n6","label":"6"}], "options": [{"item_id":"n7","label":"7"},{"item_id":"n8","label":"8"},{"item_id":"n9","label":"9"}]}'),
  ('99999999-9999-9999-9999-999999999999', 3, 'tap_registered', 2100,
   '{"target_kind": "choice", "item_id": "n8", "label": "8", "is_correct": true, "x": 210.0, "y": 640.0}'),
  ('99999999-9999-9999-9999-999999999999', 4, 'question_displayed', 3000,
   '{"question_text": "What comes next? (next_in_series)", "expected_answer": "20", "sequence": [{"item_id":"n5","label":"5"},{"item_id":"n10","label":"10"},{"item_id":"n15","label":"15"}], "options": [{"item_id":"n18","label":"18"},{"item_id":"n20","label":"20"},{"item_id":"n25","label":"25"}]}'),
  ('99999999-9999-9999-9999-999999999999', 5, 'tap_registered', 8200,
   '{"target_kind": "choice", "item_id": "n25", "label": "25", "is_correct": false, "x": 410.0, "y": 638.0}'),
  ('99999999-9999-9999-9999-999999999999', 6, 'question_displayed', 9000,
   '{"question_text": "What comes next? (next_in_series)", "expected_answer": "12", "sequence": [{"item_id":"n3","label":"3"},{"item_id":"n6b","label":"6"},{"item_id":"n9b","label":"9"}], "options": [{"item_id":"n11","label":"11"},{"item_id":"n12","label":"12"},{"item_id":"n13","label":"13"}]}'),
  ('99999999-9999-9999-9999-999999999999', 7, 'answer_submitted', 21000,
   '{"answer": "timeout", "is_correct": false}'),
  ('99999999-9999-9999-9999-999999999999', 8, 'session_completed', 21200, '{}');

select lives_ok(
  $$select public.compute_session_metrics('99999999-9999-9999-9999-999999999999')$$,
  'canonical engine computes the sequence_logic fixture');

select results_eq(
  $$select total_time_ms from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[21200], 'total_time_ms matches');

select results_eq(
  $$select accuracy from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[0.3333::numeric], 'accuracy = 1 of 3');

select results_eq(
  $$select error_count from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[2], 'errors = 1 wrong tap + 1 timeout');

select results_eq(
  $$select (extra ->> 'reaction_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1700], 'reaction = first stimulus to first tap');

select results_eq(
  $$select (extra ->> 'hesitation_count')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[1], 'the 6100ms inter-tap gap is a hesitation');

select results_eq(
  $$select (extra ->> 'total_idle_time_ms')::int from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[6100], 'idle time equals the hesitation gap');

select results_eq(
  $$select (extra ->> 'median_decision_ms')::numeric from public.session_metrics
     where session_id = '99999999-9999-9999-9999-999999999999'$$,
  array[6100::numeric], 'single decision gap is its own median');

select * from finish();
rollback;
