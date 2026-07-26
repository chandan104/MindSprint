-- Obj3 #4: add a Sequence Logic "Extreme" tier exercising the new non-linear
-- rule families (geometric, fibonacci, alternating). The generator infers these
-- rules; distractors are rule-relevant. Additive and idempotent — existing
-- Easy/Medium/Hard levels are untouched (backward compatible).

insert into public.levels (id, module_key, name, difficulty, difficulty_rank)
select v.id::uuid, 'sequence_logic', v.name, v.difficulty::public.difficulty_tier, 1
from (values
  ('00000000-0000-4000-8000-000000000421', 'Hidden Rules — Extreme', 'hard')
) as v(id, name, difficulty)
where not exists (select 1 from public.levels l where l.id = v.id::uuid);

insert into public.level_versions (level_id, version, config)
select v.level_id::uuid, 1, v.config::jsonb
from (values
  ('00000000-0000-4000-8000-000000000421',
   '{"category_key": "numbers", "logic_kinds": ["geometric", "fibonacci", "alternating"], "question_count": 8, "sequence_length": 5, "time_limit_ms_per_question": 15000}')
) as v(level_id, config)
where exists (select 1 from public.levels l where l.id = v.level_id::uuid)
  and not exists (
    select 1 from public.level_versions lv where lv.level_id = v.level_id::uuid
  );
