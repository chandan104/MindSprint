-- Assessment quality: give Pattern Detective and Visual Search a 4th "Extreme"
-- tier so every module matches the Easy/Medium/Hard/Extreme ramp the app now
-- presents. Additive and idempotent; gameplay engine + measurement unchanged.
-- (difficulty enum caps at 'hard'; the "— Extreme" name is what the app shows.)

insert into public.levels (id, module_key, name, difficulty, difficulty_rank)
select v.id::uuid, v.module_key, v.name, 'hard'::public.difficulty_tier, 1
from (values
  ('00000000-0000-4000-8000-000000000423', 'pattern_recognition',
   'Shape Patterns — Extreme'),
  ('00000000-0000-4000-8000-000000000424', 'visual_search',
   'Find the Shape — Extreme')
) as v(id, module_key, name)
where not exists (select 1 from public.levels l where l.id = v.id::uuid);

insert into public.level_versions (level_id, version, config)
select v.level_id::uuid, 1, v.config::jsonb
from (values
  -- Pattern: harder rule families, longer run, 4 options, tighter clock.
  ('00000000-0000-4000-8000-000000000423',
   '{"category_key":"shapes","pattern_kinds":["aabb","abb","mirror"],"question_count":12,"sequence_length":9,"option_count":4,"time_limit_ms_per_question":10000}'),
  -- Visual: bigger crowded grid, rarer target, faster.
  ('00000000-0000-4000-8000-000000000424',
   '{"category_key":"shapes","trial_count":14,"grid_size":36,"target_present_ratio":0.7,"time_limit_ms_per_trial":7000}')
) as v(level_id, config)
where exists (select 1 from public.levels l where l.id = v.level_id::uuid)
  and not exists (
    select 1 from public.level_versions lv where lv.level_id = v.level_id::uuid
  );
