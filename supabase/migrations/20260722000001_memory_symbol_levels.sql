-- Alphabet Recall + Number Recall as Memory Recall levels (Objective 1):
-- new levels under the existing memory_recall module, driven purely by the
-- new symbol_set / chunk_size / case_mode config knobs. Reuses the whole
-- Memory Recall pipeline — no new module, no engine change.
-- Idempotent: guarded on module existence; skips if levels already present.

insert into public.levels (id, module_key, name, difficulty, difficulty_rank)
select v.id::uuid, 'memory_recall', v.name, v.difficulty::public.difficulty_tier, 1
from (values
  ('00000000-0000-4000-8000-000000000501', 'Alphabet — Easy',    'easy'),
  ('00000000-0000-4000-8000-000000000502', 'Alphabet — Medium',  'medium'),
  ('00000000-0000-4000-8000-000000000503', 'Alphabet — Hard',    'hard'),
  ('00000000-0000-4000-8000-000000000504', 'Alphabet — Extreme', 'hard'),
  ('00000000-0000-4000-8000-000000000511', 'Numbers — Easy',     'easy'),
  ('00000000-0000-4000-8000-000000000512', 'Numbers — Medium',   'medium'),
  ('00000000-0000-4000-8000-000000000513', 'Numbers — Hard',     'hard'),
  ('00000000-0000-4000-8000-000000000514', 'Numbers — Extreme',  'hard')
) as v(id, name, difficulty)
where exists (select 1 from public.assessment_modules where module_key = 'memory_recall')
  and not exists (select 1 from public.levels l where l.id = v.id::uuid);

insert into public.level_versions (level_id, version, config)
select v.level_id::uuid, 1, v.config::jsonb
from (values
  -- Alphabet: length & smaller display as tiers rise; Hard adds mixed case,
  -- Extreme chunks letters into pairs (chunk_size 2).
  ('00000000-0000-4000-8000-000000000501', '{"symbol_set":"letters","sequence_length":3,"display_time_ms":1500,"inter_item_gap_ms":400,"choice_grid_size":6,"case_mode":"upper","trial_count":2}'),
  ('00000000-0000-4000-8000-000000000502', '{"symbol_set":"letters","sequence_length":4,"display_time_ms":1100,"inter_item_gap_ms":300,"choice_grid_size":8,"case_mode":"upper","trial_count":3}'),
  ('00000000-0000-4000-8000-000000000503', '{"symbol_set":"letters","sequence_length":5,"display_time_ms":900,"inter_item_gap_ms":250,"choice_grid_size":10,"case_mode":"mixed","trial_count":3}'),
  ('00000000-0000-4000-8000-000000000504', '{"symbol_set":"letters","sequence_length":4,"display_time_ms":800,"inter_item_gap_ms":200,"choice_grid_size":8,"case_mode":"mixed","chunk_size":2,"trial_count":3}'),
  -- Numbers: same progression; Hard uses longer runs, Extreme chunks digits.
  ('00000000-0000-4000-8000-000000000511', '{"symbol_set":"numbers","sequence_length":3,"display_time_ms":1500,"inter_item_gap_ms":400,"choice_grid_size":6,"trial_count":2}'),
  ('00000000-0000-4000-8000-000000000512', '{"symbol_set":"numbers","sequence_length":4,"display_time_ms":1100,"inter_item_gap_ms":300,"choice_grid_size":8,"trial_count":3}'),
  ('00000000-0000-4000-8000-000000000513', '{"symbol_set":"numbers","sequence_length":5,"display_time_ms":900,"inter_item_gap_ms":250,"choice_grid_size":10,"trial_count":3}'),
  ('00000000-0000-4000-8000-000000000514', '{"symbol_set":"numbers","sequence_length":4,"display_time_ms":800,"inter_item_gap_ms":200,"choice_grid_size":8,"chunk_size":2,"trial_count":3}')
) as v(level_id, config)
where exists (select 1 from public.levels l where l.id = v.level_id::uuid)
  and not exists (
    select 1 from public.level_versions lv where lv.level_id = v.level_id::uuid
  );
