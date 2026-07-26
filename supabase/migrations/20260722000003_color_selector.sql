-- Objective 2: Colour Selector module + its feature flag + E/M/H/Extreme
-- levels. Generated content (no category). Idempotent.

insert into public.assessment_modules (module_key, name, enabled)
values ('color_selector', 'Colour Selector', true)
on conflict (module_key) do nothing;

insert into public.feature_flags (key, enabled, description)
values ('color_selector_module', true, 'Colour Selector (selective attention) module')
on conflict (key) do update set enabled = true;

insert into public.levels (id, module_key, name, difficulty, difficulty_rank)
select v.id::uuid, 'color_selector', v.name, v.difficulty::public.difficulty_tier, 1
from (values
  ('00000000-0000-4000-8000-000000000601', 'Colours — Easy',    'easy'),
  ('00000000-0000-4000-8000-000000000602', 'Colours — Medium',  'medium'),
  ('00000000-0000-4000-8000-000000000603', 'Colours — Hard',    'hard'),
  ('00000000-0000-4000-8000-000000000604', 'Colours — Extreme', 'hard')
) as v(id, name, difficulty)
where not exists (select 1 from public.levels l where l.id = v.id::uuid);

insert into public.level_versions (level_id, version, config)
select v.level_id::uuid, 1, v.config::jsonb
from (values
  ('00000000-0000-4000-8000-000000000601', '{"colour_count":3,"time_limit_ms_per_round":8000,"stroop":false,"instruction_modes":["colour"]}'),
  ('00000000-0000-4000-8000-000000000602', '{"colour_count":5,"time_limit_ms_per_round":5000,"stroop":false,"instruction_modes":["colour"]}'),
  ('00000000-0000-4000-8000-000000000603', '{"colour_count":4,"time_limit_ms_per_round":5000,"stroop":true,"instruction_modes":["word"]}'),
  ('00000000-0000-4000-8000-000000000604', '{"colour_count":6,"time_limit_ms_per_round":3500,"stroop":true,"instruction_modes":["colour","word"]}')
) as v(level_id, config)
where exists (select 1 from public.levels l where l.id = v.level_id::uuid)
  and not exists (
    select 1 from public.level_versions lv where lv.level_id = v.level_id::uuid
  );
