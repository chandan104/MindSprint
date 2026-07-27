-- UX/assessment quality: Focus Tap was too easy. Rebalance so the old Hard is
-- roughly the new Easy, with a clear Easy→Medium→Hard→Extreme progression
-- (shorter response windows, more stimuli, rarer targets, tighter gaps).
--
-- level_versions is append-only (M3 trigger), and the app always plays the
-- HIGHEST version of each level, so we INSERT version 2 rather than updating —
-- fully reversible (delete the v2 rows to fall back to v1) and non-destructive.
-- Shorter display_time_ms = shorter reaction window = harder.

insert into public.level_versions (level_id, version, config)
select v.level_id::uuid, 2, v.config::jsonb
from (values
  -- Animal Watch — Easy  (was 2000ms/15/0.5 → now ~old-Hard territory)
  ('00000000-0000-4000-8000-000000000407',
   '{"category_key":"animals","stimulus_count":22,"target_ratio":0.4,"display_time_ms":900,"inter_stimulus_gap_ms":350}'),
  -- Fruit Watch — Medium
  ('00000000-0000-4000-8000-000000000408',
   '{"category_key":"fruits","stimulus_count":32,"target_ratio":0.3,"display_time_ms":700,"inter_stimulus_gap_ms":280}'),
  -- Shape Watch — Hard
  ('00000000-0000-4000-8000-000000000409',
   '{"category_key":"shapes","stimulus_count":42,"target_ratio":0.25,"display_time_ms":550,"inter_stimulus_gap_ms":230}')
) as v(level_id, config)
where exists (select 1 from public.levels l where l.id = v.level_id::uuid)
  and not exists (
    select 1 from public.level_versions lv
    where lv.level_id = v.level_id::uuid and lv.version = 2
  );

-- New Extreme tier (difficulty enum caps at 'hard'; the "— Extreme" name is what
-- the app displays, matching the Memory Recall Extreme levels).
insert into public.levels (id, module_key, name, difficulty, difficulty_rank)
select '00000000-0000-4000-8000-000000000422'::uuid, 'attention_focus',
       'Focus Watch — Extreme', 'hard'::public.difficulty_tier, 1
where not exists (
  select 1 from public.levels where id = '00000000-0000-4000-8000-000000000422'::uuid
);

insert into public.level_versions (level_id, version, config)
select '00000000-0000-4000-8000-000000000422'::uuid, 1,
       '{"category_key":"shapes","stimulus_count":55,"target_ratio":0.2,"display_time_ms":420,"inter_stimulus_gap_ms":180}'::jsonb
where exists (
  select 1 from public.levels where id = '00000000-0000-4000-8000-000000000422'::uuid
) and not exists (
  select 1 from public.level_versions where level_id = '00000000-0000-4000-8000-000000000422'::uuid
);
