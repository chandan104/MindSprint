-- Obj3 #3: add a Mathematics Speed "Extreme" tier. Multiplication + exact
-- division, wider operands, tighter clock — the generator already produces
-- integer-safe division and miscalculation-based distractors. Additive and
-- idempotent; existing Easy/Medium/Hard levels are untouched (backward
-- compatible, historical scores unaffected).

insert into public.levels (id, module_key, name, difficulty, difficulty_rank)
select v.id::uuid, 'math_speed', v.name, v.difficulty::public.difficulty_tier, 1
from (values
  ('00000000-0000-4000-8000-000000000420', 'Times & Division — Extreme', 'hard')
) as v(id, name, difficulty)
where not exists (select 1 from public.levels l where l.id = v.id::uuid);

insert into public.level_versions (level_id, version, config)
select v.level_id::uuid, 1, v.config::jsonb
from (values
  ('00000000-0000-4000-8000-000000000420',
   '{"operations": ["mul", "div"], "question_count": 12, "operand_min": 3, "operand_max": 15, "time_limit_ms_per_question": 8000}')
) as v(level_id, config)
where exists (select 1 from public.levels l where l.id = v.level_id::uuid)
  and not exists (
    select 1 from public.level_versions lv where lv.level_id = v.level_id::uuid
  );
